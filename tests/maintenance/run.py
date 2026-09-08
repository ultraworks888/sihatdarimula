#!/usr/bin/env python3
"""Real PB 0.29.3 acceptance suite. All data and instrumentation stay in work/.

Usage: python3 tests/maintenance/run.py --binary work/maintenance/bin/pocketbase
No production credentials, endpoints, data, or schema fixtures are used.
"""
import argparse
import concurrent.futures
from datetime import datetime, timezone
import hashlib
import hmac
import json
import os
from pathlib import Path
import re
import shutil
import socket
import sqlite3
import subprocess
import threading
import time
import urllib.error
import urllib.request
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = Path(__file__).resolve().parents[2]
MESSAGE = "Service temporarily unavailable for maintenance."
RESULTS = []
SECRETS = []
OBSERVATIONS = {}


def check(condition, name):
    if not condition:
        raise AssertionError(name)
    RESULTS.append(name)
    print("PASS " + name, flush=True)


class Provider(BaseHTTPRequestHandler):
    calls = []
    pause_entered = threading.Event()
    pause_release = threading.Event()
    after_send = False
    unexpected = 0
    error_response = False

    def log_message(self, *_):
        pass

    def do_POST(self):
        if self.path not in ("/pause", "/provider"):
            type(self).unexpected += 1
            self.send_error(403)
            return
        body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        if self.path == "/pause":
            self.pause_entered.set()
            self.pause_release.wait(15)
        else:
            self.calls.append(json.loads(body or b"{}"))
            if self.after_send:
                self.pause_entered.set()
                self.pause_release.wait(15)
        response = {"messages": [{"id": "stub-message"}], "id": "stub-push",
                    "recipients": 1, "candidates": [{"content": {"parts": [{"text": "Stub answer"}]}}]}
        data = json.dumps(response).encode()
        self.send_response(502 if self.error_response else 200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_CONNECT(self):
        type(self).unexpected += 1
        self.send_error(403)


class Runtime:
    def __init__(self, binary):
        self.binary = str(binary.resolve())
        started = datetime.now(timezone.utc)
        self.run_id = started.strftime("%Y%m%dT%H%M%SZ") + "-" + uuid.uuid4().hex
        runs = ROOT / "work/maintenance/runs"
        runs.mkdir(parents=True, exist_ok=True)
        self.base = runs / self.run_id
        self.base.mkdir(exist_ok=False)
        self.manifest = {"run_id": self.run_id, "utc_start": started.isoformat(),
                         "git_head": subprocess.check_output(
                             ["git", "rev-parse", "HEAD"], cwd=ROOT,
                             stderr=subprocess.DEVNULL, text=True).strip(),
                         "pocketbase_version": "not yet verified", "mode": "local-only"}
        self.write_manifest()
        print("RUN " + str(self.base), flush=True)
        self.data = self.base / "data"
        self.hooks = self.base / "hooks"
        self.migrations = self.base / "migrations"
        shutil.copytree(ROOT / "pb_hooks", self.hooks)
        shutil.copytree(ROOT / "pb_migrations", self.migrations)
        ThreadingHTTPServer.request_queue_size = 128
        self.provider = ThreadingHTTPServer(("127.0.0.1", 0), Provider)
        threading.Thread(target=self.provider.serve_forever, daemon=True).start()
        self.stub = "http://127.0.0.1:" + str(self.provider.server_port)
        # Defense in depth: any missed HTTP(S) destination is sent to a local
        # deny proxy, never a provider. Loopback requests bypass the proxy.
        self.env = dict(os.environ, HTTP_PROXY=self.stub, HTTPS_PROXY=self.stub,
                        http_proxy=self.stub, https_proxy=self.stub,
                        NO_PROXY="127.0.0.1,localhost", no_proxy="127.0.0.1,localhost")
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            self.port = sock.getsockname()[1]
        self.url = "http://127.0.0.1:" + str(self.port)
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        self.process = None
        self.log = None
        self.super_token = ""
        self.password = "Local-Test-Password-872!"
        SECRETS.append(self.password)
        self.instrument()

    def write_manifest(self):
        (self.base / "manifest.json").write_text(json.dumps(self.manifest, indent=2))

    def command(self, *args, input=None):
        result = subprocess.run([self.binary, *args, "--dir=" + str(self.data),
                                 "--hooksDir=" + str(self.hooks),
                                 "--migrationsDir=" + str(self.migrations), "--hooksWatch=false"],
                                input=input, capture_output=True, text=True, timeout=40, env=self.env)
        with (self.base / "commands.log").open("a") as log:
            log.write(result.stdout + result.stderr)
        if result.returncode:
            raise RuntimeError("Disposable PocketBase command failed: " + args[0])
        return result.stdout

    def instrument(self):
        # Only the copied helper is instrumented. Guards and all route bodies
        # are unchanged. Redirect every provider send to the loopback stub.
        path = self.hooks / "maintenance.js"
        source = path.read_text()
        source = source.replace("return $http.send(options);",
                                "options.url = " + json.dumps(self.stub + "/provider") + "; return $http.send(options);")
        # Deterministic seam AFTER request entry check, BEFORE route body.
        source = source.replace("assertOpen(e.app);\n      return action();", """assertOpen(e.app);
    if (e.request && $app.store().get('test.pause') === e.request.url.path) {
      $app.store().remove('test.pause');
      $http.send({url: PAUSE_URL, method: 'POST', body: '{}', timeout: 20});
    }
    return action();""".replace("PAUSE_URL", json.dumps(self.stub + "/pause")), 1)
        # Inject a thrown read error inside the helper's existing try/catch.
        source = source.replace("function isOpen(app) {\n  try {",
                                "function isOpen(app) {\n  try {\n    if ($app.store().get('test.readFailure')) throw new Error('simulated read failure');", 1)
        source = source.replace("function status(app) {", "function status(app) {\n" +
            "  if ($app.store().get('test.readFailure')) return {admission_closed:true,drained:false,state_valid:false,in_flight_prohibited_operations:null};", 1)
        source = source.replace("try { return action(); }", """try {
  if ($app.store().get('test.holdKind') === kind) {
    $http.send({url: PAUSE_URL, method:'POST', body:'{}', timeout:20});
  }
  return action(); }""".replace("PAUSE_URL", json.dumps(self.stub + "/pause")), 1)
        source = source.replace("} catch (_) {\n    throw new Error(message);", """} catch (_) {
    const reason = /locked|busy/i.test(String(_)) ? 'sqlite-contention' :
      String(_).indexOf(message) >= 0 ? 'maintenance-closed' : 'unexpected-admission-error';
    $app.store().set('test.admissionError.' + kind, reason);
    throw new Error(message);""", 1)
        source = source.replace("send: function(options) { assertOpen($app);",
            """send: function(options) { assertOpen($app);
    if ($app.store().get('test.afterCheck')) {
      $app.store().remove('test.afterCheck');
      $http.send({url: PAUSE_URL, method: 'POST', body: '{}', timeout: 20});
    }""".replace("PAUSE_URL", json.dumps(self.stub + "/pause")), 1)
        path.write_text(source)
        (self.hooks / "zz_test_only.pb.js").write_text("""
// Disposable loopback fixture only. Never copied into project pb_hooks.
onMailerSend(function(e) {
  $app.store().set('test.mail', Number($app.store().get('test.mail') || 0) + 1);
  if ($app.store().get('test.mailPause')) {
    $app.store().remove('test.mailPause');
    $http.send({url:'__PAUSE_URL__', method:'POST', body:'{}', timeout:20});
  }
});
routerAdd('POST', '/__test/control', function(e) {
  if (!e.hasSuperuserAuth()) return e.json(403, {});
  const body = e.requestInfo().body;
  if (body.pause !== undefined) $app.store().set('test.pause', body.pause);
  if (body.readFailure !== undefined) $app.store().set('test.readFailure', body.readFailure);
  if (body.afterCheck !== undefined) $app.store().set('test.afterCheck', body.afterCheck);
  if (body.holdKind !== undefined) $app.store().set('test.holdKind', body.holdKind);
  if (body.mailPause !== undefined) $app.store().set('test.mailPause', body.mailPause);
  if (body.flushLogs) $app.logger().handler().writeAll();
  if (body.cron) {
    const jobs = $app.cron().jobs();
    for (let i = 0; i < jobs.length; i++) if (jobs[i].id() === body.cron) jobs[i].run();
  }
  return e.json(200, {mail: Number($app.store().get('test.mail') || 0),
    cronAdmissionError: $app.store().get('test.admissionError.cron') || ''});
});
// Fault injection stays in this copied local hook and executes under an actual
// custom HTTP admission; it never appears in the deployable hook directory.
routerAdd('POST', '/__test/failure', function(e) {
  if (!e.hasSuperuserAuth()) return e.json(403, {});
  return require(__hooks + '/maintenance.js').http(e, function() {
    const kind = e.requestInfo().body.kind;
    if (kind === 'throw') throw new Error('synthetic execution failure');
    if (kind === 'db') $app.db().newQuery('SELECT * FROM nonexistent_local_fixture').execute();
    return e.json(422, {message:'synthetic early return'});
  });
});
onRecordCreateExecute(function(e) {
  if ($app.store().get('test.dbPause') && e.record.collection().name === 'children') {
    $app.store().remove('test.dbPause');
    $http.send({url: '__PAUSE_URL__', method:'POST', body:'{}', timeout:20});
  }
  e.next();
});
""")
        test_hook = self.hooks / "zz_test_only.pb.js"
        test_hook.write_text(test_hook.read_text().replace("__PAUSE_URL__", self.stub + "/pause").replace(
            "if (body.pause !== undefined)", "if (body.dbPause !== undefined) $app.store().set('test.dbPause', body.dbPause);\n  if (body.pause !== undefined)"))

    def start(self):
        self.log = (self.base / "runtime.log").open("a")
        self.process = subprocess.Popen([self.binary, "serve", "--http=127.0.0.1:" + str(self.port),
                                         "--dir=" + str(self.data), "--hooksDir=" + str(self.hooks),
                                         "--migrationsDir=" + str(self.migrations), "--hooksWatch=false"],
                                        stdout=self.log, stderr=subprocess.STDOUT, env=self.env)
        for _ in range(100):
            if self.process.poll() is not None:
                raise RuntimeError("Disposable PocketBase did not start; inspect runtime.log")
            try:
                if self.request("GET", "/api/health")[0] == 200:
                    return
            except OSError:
                pass
            time.sleep(.1)
        raise RuntimeError("Disposable PocketBase startup timed out")

    def stop(self):
        if self.process and self.process.poll() is None:
            self.process.terminate()
            self.process.wait(timeout=10)
        if self.log:
            self.log.close()

    def request(self, method, path, body=None, token="", headers=None):
        data = None if body is None else json.dumps(body).encode()
        hdr = {"Content-Type": "application/json", "User-Agent": "maintenance-local-test"}
        if token:
            hdr["Authorization"] = token
        hdr.update(headers or {})
        request = urllib.request.Request(self.url + path, data=data, method=method, headers=hdr)
        try:
            response = self.opener.open(request, timeout=25)
        except urllib.error.HTTPError as error:
            response = error
        raw = response.read()
        try:
            payload = json.loads(raw)
        except ValueError:
            payload = raw.decode()
        return response.status, payload, dict(response.headers)

    def admin(self, method, path, body=None):
        result = self.request(method, path, body, self.super_token)
        if result[0] >= 300:
            raise RuntimeError("Local fixture setup failed: " + method + " " + path + " status=" + str(result[0]))
        return result[1]

    def create(self, collection, body):
        return self.admin("POST", "/api/collections/" + collection + "/records", body)

    def patch(self, collection, record_id, body):
        return self.admin("PATCH", "/api/collections/" + collection + "/records/" + record_id, body)

    def setting(self, value):
        return self.patch("lms_settings", self.setting_id, {"value": value})

    def rows(self, table):
        with sqlite3.connect("file:" + str(self.data / "data.db") + "?mode=ro", uri=True) as db:
            db.row_factory = sqlite3.Row
            return [dict(row) for row in db.execute('SELECT * FROM "' + table + '" ORDER BY id')]

    def sql(self, statement, params=()):
        with sqlite3.connect(str(self.data / "data.db")) as db:
            return db.execute(statement, params).fetchall()

    def snapshot(self):
        # All application data plus built-in auth state. Exclude only settings
        # (operator toggle) and PB metadata; logs are in the separate aux DB.
        with sqlite3.connect("file:" + str(self.data / "data.db") + "?mode=ro", uri=True) as db:
            tables = [r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table'")]
        result = {t: self.rows(t) for t in tables if not t.startswith("sqlite_") and
                  t not in ["_collections", "_params", "_migrations", "maintenance_inflight", "_test_admission_audit"]}
        # Exclude only the operator toggle, not configuration/provider settings.
        result["lms_settings"] = [row for row in result["lms_settings"] if row["key"] != "maintenance_mode"]
        return result

    def login(self, email, password=None, collection="users"):
        result = self.request("POST", "/api/collections/" + collection + "/auth-with-password",
                              {"identity": email, "password": password or self.password})
        if result[0] != 200:
            raise RuntimeError("Local fixture login failed: status=" + str(result[0]))
        SECRETS.append(result[1]["token"])
        return result[1]["token"], result[1]["record"]

    def upsert_setting(self, key, value):
        rows = [x for x in self.rows("lms_settings") if x["key"] == key]
        if rows:
            return self.patch("lms_settings", rows[0]["id"], {"value": value})
        return self.create("lms_settings", {"key": key, "value": value})

    def user(self, label, phone="", role="user"):
        email = label + "@example.test"
        u = self.create("users", {"email": email, "password": self.password,
                                 "passwordConfirm": self.password, "name": "Local Fixture",
                                 "language": "en", "role": role})
        if phone:
            u = self.patch("users", u["id"], {"phone": phone})
            SECRETS.extend([phone, phone.lstrip("+")])
        token, _ = self.login(email)
        return u, token


def blocked(result, name):
    status, body, headers = result
    check(status == 503 and body == {"message": MESSAGE}
          and headers.get("Retry-After") == "3600"
          and headers.get("Cache-Control") == "no-store", name)


def main():
    args = argparse.ArgumentParser()
    args.add_argument("--binary", type=Path, required=True)
    args.add_argument("--probe", action="store_true", help="Only establish runtime/fixture capabilities")
    options = args.parse_args()
    runtime = None
    try:
        inventory()
        r = runtime = Runtime(options.binary)
        version = r.command("--version").strip()
        check(re.search(r"\b0\.29\.3\b", version) is not None, "PocketBase version 0.29.3")
        r.manifest["pocketbase_version"] = "0.29.3"
        r.manifest["mode"] = "local-only-probe" if options.probe else "local-only-acceptance"
        r.write_manifest()
        r.command("migrate", "up")
        if not options.probe:
            migration_acceptance(r)
        r.command("superuser", "create", "operator@example.test", r.password)
        r.start()
        r.super_token, _ = r.login("operator@example.test", collection="_superusers")
        settings = r.admin("GET", "/api/collections/lms_settings/records?filter=key%3D%27maintenance_mode%27")
        r.setting_id = settings["items"][0]["id"]
        if options.probe:
            print("PROBE: native auth, module entry and health available", flush=True)
            r.setting("true")
            print("PROBE: blocked registration status=" + str(r.request("POST", "/api/collections/users/records", {})[0]), flush=True)
            print("PROBE: cron invocation status=" + str(r.admin("POST", "/__test/control", {"cron": "push_reminder_daily"})), flush=True)
            return
        acceptance(r)
        OBSERVATIONS["verdict"] = "PASS"
    except Exception as error:
        OBSERVATIONS["verdict"] = "BLOCKED"
        OBSERVATIONS["failure"] = str(error)
        print("BLOCKED: " + str(error), flush=True)
        raise SystemExit(1)
    finally:
        if runtime:
            runtime.stop()
            runtime.provider.shutdown()
            (runtime.base / "results.json").write_text(json.dumps(
                {"passed": RESULTS, "observations": OBSERVATIONS}, indent=2))
            (runtime.base / "provider-summary.json").write_text(json.dumps(
                {"total_calls": len(Provider.calls), "raw_payloads_persisted": False}, indent=2))


def migration_acceptance(r):
    filename = "1788676088_seed_maintenance_mode_setting_bd01.js"
    state = lambda: r.sql("SELECT value FROM lms_settings WHERE key='maintenance_mode'")
    history = lambda: r.sql("SELECT file FROM _migrations WHERE file=?", (filename,))
    check(state() == [("false",)] and len(history()) == 1, "migration fresh UP seeds one false")
    r.command("migrate", "up")
    check(state() == [("false",)] and len(history()) == 1, "migration repeated UP is no-op")
    r.sql("UPDATE lms_settings SET value='true' WHERE key='maintenance_mode'")
    r.command("migrate", "up")
    check(state() == [("true",)], "migration already-recorded filename preserves true")
    r.sql("INSERT INTO maintenance_inflight (id,kind,admitted_at) VALUES ('stalefixture001','http','2000-01-01 00:00:00Z')")
    r.command("migrate", "down", "2", input="y\n")
    check(state() == [("true",)] and not history(), "migration DOWN preserves operator state")
    check(len(r.sql("SELECT id FROM maintenance_inflight")) == 1, "coordination DOWN preserves stale record and schema")
    r.command("migrate", "up")
    check(state() == [("true",)] and len(history()) == 1, "migration reapply preserves existing true")
    check(len(r.sql("SELECT id FROM maintenance_inflight")) == 1, "coordination reapply preserves existing operation")
    r.sql("DELETE FROM maintenance_inflight WHERE id='stalefixture001'")  # synthetic, no process was ever admitted
    r.sql("UPDATE lms_settings SET value='false' WHERE key='maintenance_mode'")


MUTATIONS = [
    ("POST", "/api/chat/ask"),
    ("POST", "/api/admin/whatsapp/config"),
    ("DELETE", "/api/admin/whatsapp/config"),
    ("POST", "/api/lms/send-reminders"),
    ("POST", "/api/whatsapp/send-welcome"),
    ("POST", "/api/whatsapp/send-milestone-reminders"),
    ("POST", "/api/admin/whatsapp/meta-blast"),
    ("POST", "/api/admin/push-broadcast"),
    ("POST", "/api/admin/push-broadcast/cancel"),
    ("POST", "/api/auth/request-whatsapp-otp"),
    ("POST", "/api/auth/verify-whatsapp-otp"),
    ("POST", "/api/auth/request-password-reset-whatsapp"),
    ("POST", "/api/auth/confirm-password-reset-whatsapp"),
]
READS = ["/api/admin/analytics", "/api/admin/export?type=users", "/api/admin/ai/config",
         "/api/admin/whatsapp/config", "/api/lms/reminder-status"]
JOBS = ["phone_verification_otp_cleanup", "password_reset_otp_cleanup",
        "push_reminder_daily", "push_broadcast_scheduler"]


def inventory():
    sources = {p.name: p.read_text() for p in (ROOT / "pb_hooks").glob("*.pb.js")}
    routes = [(m, path, name) for name, s in sources.items() for m, path in
              re.findall(r'routerAdd\("(\w+)",\s*"([^"]+)"', s)]
    check(len(routes) == 20 and sum(p == "/api/maintenance/status" for _, p, _ in routes) == 1,
          "static inventory: 19 application routes plus one native-only drain status")
    for method, route in MUTATIONS:
        matches = [name for m, p, name in routes if (m, p) == (method, route)]
        check(len(matches) == 1 and re.search(
            r'routerAdd\("' + method + r'",\s*"' + re.escape(route) +
            r'"[^\n]*\{\s*return require\(__hooks \+ "/maintenance.js"\)\.http',
            sources[matches[0]]), "static entry guard " + method + " " + route)
    actual_jobs = [j for s in sources.values() for j in re.findall(r'cronAdd\("([^"]+)"', s)]
    check(sorted(actual_jobs) == sorted(JOBS), "static inventory: four guarded cron jobs")
    check(sum(s.count('.background(function()') for s in sources.values()) == 4 and
          sources["meta_whatsapp.pb.js"].count('.event(e, function()') == 2,
          "static background guard coverage")
    check(all("$http.send(" not in s for s in sources.values()), "all project provider sends use shared guard")
    check('.http(e,' not in sources["whatsapp_webhook.pb.js"], "webhook ingestion intentionally allowed")
    OBSERVATIONS["route_inventory"] = routes


def fixture(r):
    for key, value in {"whatsapp_phone_number_id": "local-phone-id",
                       "whatsapp_access_token": "local-only-provider-secret-913",
                       "whatsapp_api_version": "v20.0", "onesignal_app_id": "local-push-id",
                       "onesignal_api_key": "local-only-push-secret-914",
                       "app_url": r.url}.items():
        r.upsert_setting(key, value)
        if "token" in key or "key" in key:
            SECRETS.append(value)
    ai = r.rows("ai_settings")[0]
    r.patch("ai_settings", ai["id"], {"gemini_key": "local-only-ai-secret-915"})
    SECRETS.append("local-only-ai-secret-915")
    # The secrets migration was quarantined. Recreate only a synthetic local
    # locked collection, never importing production configuration.
    r.admin("POST", "/api/collections", {"name": "whatsapp_server_secrets", "type": "base",
            "fields": [{"name": "key", "type": "text"}, {"name": "value", "type": "text"}]})
    r.webhook_secret = "local-only-webhook-secret-916"
    SECRETS.append(r.webhook_secret)
    r.create("whatsapp_server_secrets", {"key": "wa_internal_forward_secret", "value": r.webhook_secret})
    for event in ["user_registration", "course_enrollment", "course_completion", "course_reminder"]:
        r.create("whatsapp_templates", {"display_name": "Local " + event, "trigger_event": event,
                 "meta_template_name": "local_template", "language_code": "en", "variables": [],
                 "approval_status": "approved", "is_active": True})
    r.normal, r.token = r.user("ordinary")
    r.admin_user, r.admin_token = r.user("app-admin", role="admin")
    r.super_user, r.app_super_token = r.user("app-superadmin", role="superadmin")
    r.course = r.create("courses", {"title_en": "Local course", "is_published": True})
    r.child = r.create("children", {"user": r.normal["id"], "name": "Local child"})
    check(True, "hook load: native auth and synthetic fixture setup")


def status(result, expected, name):
    check(result[0] == expected, name + " status=" + str(result[0]))


def webhook(r, suffix):
    body = {"object": "whatsapp_business_account", "entry": [{"id": "local-entry", "changes": [
        {"field": "messages", "value": {"statuses": [{"id": "local-" + suffix,
                                                     "status": "delivered"}]}}]}]}
    digest = hashlib.sha256(json.dumps(body).encode()).hexdigest()
    timestamp = str(int(time.time()))
    signature = hmac.new(r.webhook_secret.encode(), (timestamp + "." + digest).encode(), hashlib.sha256).hexdigest()
    SECRETS.extend([digest, signature])
    before = len(r.rows("whatsapp_webhook_events"))
    response = r.request("POST", "/api/whatsapp/webhook", body, headers={
        "X-WhatsApp-Timestamp": timestamp, "X-WhatsApp-Body-Digest": digest,
        "X-WhatsApp-Signature": signature})
    check(response[0] == 200 and len(r.rows("whatsapp_webhook_events")) == before + 1,
          "authenticated webhook " + suffix)
    status(r.request("POST", "/api/whatsapp/webhook", body), 401, "unauthenticated webhook rejected " + suffix)


def off_acceptance(r):
    r.setting("false")
    for user, token in [(r.normal, r.token), (r.admin_user, r.admin_token)]:
        before = next(x for x in r.rows("users") if x["id"] == user["id"])
        path = "/api/collections/users/records/" + user["id"]
        status(r.request("PATCH", path, {"role": "superadmin", "name": "Must not persist"}, token),
               403, "OFF unauthorized mixed role write rejected")
        check(next(x for x in r.rows("users") if x["id"] == user["id"]) == before,
              "OFF mixed role rejection remains atomic")
    path = "/api/collections/users/records/" + r.normal["id"]
    status(r.request("PATCH", path, {"name": "Local ordinary update"}, r.token),
           200, "OFF ordinary profile update unaffected")
    status(r.request("PATCH", path, {"phone_verified": True, "name": "Must not persist"}, r.token),
           403, "OFF server-managed verified phone write rejected")
    check(next(x for x in r.rows("users") if x["id"] == r.normal["id"])["name"] == "Local ordinary update",
          "OFF forbidden verification write rejects other fields atomically")
    # A separate target avoids changing auth roles used by later gate tests.
    target, _ = r.user("role-target")
    status(r.request("PATCH", "/api/collections/users/records/" + target["id"],
                     {"role": "admin"}, r.app_super_token), 200,
           "OFF authorized application superadmin cross-user role update")
    response = r.request("POST", "/api/collections/children/records",
                         {"user": r.normal["id"], "name": "CRUD fixture"}, r.token)
    status(response, 200, "OFF create")
    path = "/api/collections/children/records/" + response[1]["id"]
    status(r.request("PATCH", path, {"name": "CRUD updated"}, r.token), 200, "OFF update")
    status(r.request("DELETE", path, token=r.token), 204, "OFF delete")
    status(r.request("POST", "/api/collections/users/records", {"email": "registered@example.test",
           "password": r.password, "passwordConfirm": r.password}), 200, "OFF registration")
    r.login("registered@example.test")
    check(True, "OFF password login")
    status(r.request("POST", "/api/collections/users/auth-refresh", {}, r.token), 200, "OFF refresh")
    r.phone = "+60123456789"
    SECRETS.extend([r.phone, r.phone[1:]])
    before = len(Provider.calls)
    status(r.request("POST", "/api/auth/request-whatsapp-otp", {"phone": r.phone}, r.token), 200, "OFF OTP initiation")
    check(len(Provider.calls) == before + 1, "OFF OTP provider called once")
    code = Provider.calls[-1]["template"]["components"][0]["parameters"][0]["text"]
    SECRETS.append(code)
    status(r.request("POST", "/api/auth/verify-whatsapp-otp", {"phone": r.phone, "code": code}, r.token), 200, "OFF OTP verification")
    user = next(x for x in r.rows("users") if x["id"] == r.normal["id"])
    check(user["phone"] == r.phone and user["phone_verified"] == 1, "OFF canonical verified phone persisted")
    before = len(Provider.calls)
    status(r.request("POST", "/api/auth/request-password-reset-whatsapp", {"phone": r.phone}), 200, "OFF reset initiation")
    check(len(Provider.calls) == before + 1, "OFF reset provider called once")
    code = Provider.calls[-1]["template"]["components"][0]["parameters"][0]["text"]
    SECRETS.append(code)
    new_password = "New-Local-Test-Password-873!"
    SECRETS.append(new_password)
    status(r.request("POST", "/api/auth/confirm-password-reset-whatsapp",
                     {"phone": r.phone, "code": code, "password": new_password}), 200, "OFF reset confirmation")
    r.token, _ = r.login("ordinary@example.test", new_password)
    check(True, "OFF reset password works")
    for path, body, token in [
        ("/api/chat/ask", {"message": "Local fixture question"}, r.token),
        ("/api/whatsapp/send-welcome", {}, r.token),
    ]:
        before = len(Provider.calls)
        status(r.request("POST", path, body, token), 200, "OFF " + path)
        check(len(Provider.calls) == before + 1, "OFF provider delivery " + path)
    response = r.request("POST", "/api/admin/push-broadcast", {"title": "Local scheduled",
                         "message": "Local scheduled message", "scheduled_at": "2099-01-01 00:00:00Z"}, r.admin_token)
    status(response, 200, "OFF schedule push")
    record = next(x for x in r.rows("push_broadcasts") if x["title"] == "Local scheduled")
    status(r.request("POST", "/api/admin/push-broadcast/cancel", {"id": record["id"]}, r.admin_token), 200, "OFF cancel push")
    status(r.request("POST", "/api/admin/whatsapp/config", {"api_version": "v20.0"}, r.admin_token), 200, "OFF configuration write")
    status(r.request("POST", "/api/lms/send-reminders", {}), 200, "OFF LMS route remains unchanged")
    webhook(r, "off")


def assert_unchanged(r, before, calls, name):
    check(r.snapshot() == before, name + " zero application/auth-state mutations")
    check(len(Provider.calls) == calls, name + " zero provider calls")


def on_acceptance(r):
    r.setting("true")
    before, calls = r.snapshot(), len(Provider.calls)
    path = "/api/collections/children/records/" + r.child["id"]
    builtins = [("POST", "/api/collections/children/records", {"user": r.normal["id"], "name": "blocked"}),
                ("PATCH", path, {"name": "blocked"}), ("DELETE", path, {}),
                ("POST", "/api/collections/users/records", {}),
                ("POST", "/api/collections/users/auth-with-password", {}),
                ("POST", "/api/collections/users/auth-refresh", {}),
                ("POST", "/api/batch", {"requests": []})]
    for method, path, body in builtins:
        blocked(r.request(method, path, body, r.token), "ON " + method + " " + path)
    for method, path in MUTATIONS:
        blocked(r.request(method, path, {"phone": r.phone, "message": "blocked"}, r.admin_token),
                "ON " + method + " " + path)
    assert_unchanged(r, before, calls, "ON blocked routes")
    for path in READS:
        status(r.request("GET", path, token=r.admin_token), 200, "ON read " + path)
    status(r.request("GET", "/api/health"), 200, "ON health")
    webhook(r, "on")
    OBSERVATIONS["provider_calls_while_ON_blocked_routes"] = len(Provider.calls) - calls


def fail_closed_acceptance(r):
    route = "/api/chat/ask"
    for value in ["true", "TRUE", "False", " false ", "", "null", "0"]:
        r.setting(value)
        blocked(r.request("POST", route, {"message": "blocked"}, r.token), "fail-closed value " + repr(value))
    r.admin("DELETE", "/api/collections/lms_settings/records/" + r.setting_id)
    blocked(r.request("POST", route, {}, r.token), "fail-closed missing")
    r.setting_id = r.create("lms_settings", {"key": "maintenance_mode", "value": "false"})["id"]
    duplicate = r.create("lms_settings", {"key": "maintenance_mode", "value": "false"})
    blocked(r.request("POST", route, {}, r.token), "fail-closed duplicate")
    r.admin("DELETE", "/api/collections/lms_settings/records/" + duplicate["id"])
    r.admin("POST", "/__test/control", {"readFailure": True})
    blocked(r.request("POST", route, {}, r.token), "fail-closed lookup exception")
    for path in READS:
        status(r.request("GET", path, token=r.admin_token), 200, "lookup failure does not block read " + path)
    r.admin("POST", "/__test/control", {"readFailure": False})
    status(r.request("POST", route, {"message": "restored"}, r.token), 200, "exact false restores without restart")


def concurrency_and_bypass(r):
    r.setting("true")
    before, calls = r.snapshot(), len(Provider.calls)
    with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
        results = list(pool.map(lambda i: r.request(*MUTATIONS[i % len(MUTATIONS)], {}, r.token), range(39)))
    for i, result in enumerate(results):
        blocked(result, "concurrent blocked request " + str(i))
    for label, token, headers, query, body in [
        ("ordinary", r.token, {}, "", {}),
        ("app admin", r.admin_token, {}, "", {}),
        ("app superadmin", r.app_super_token, {}, "", {}),
        ("fake forwarded IP", "", {"X-Forwarded-For": "127.0.0.1"}, "", {}),
        ("arbitrary headers", "", {"X-Maintenance-Bypass": "true", "X-Role": "superadmin"}, "", {}),
        ("query flags", "", {}, "?maintenance=false&role=superadmin", {}),
        ("body role", "", {}, "", {"role": "superadmin", "maintenance_mode": "false"}),
    ]:
        blocked(r.request("POST", "/api/auth/request-whatsapp-otp" + query, body, token, headers), "bypass rejected " + label)
        blocked(r.request("POST", "/api/collections/users/records" + query, body, token, headers), "builtin bypass rejected " + label)
    assert_unchanged(r, before, calls, "concurrency and bypass")
    OBSERVATIONS["concurrent_blocked_requests"] = len(results)


def transition_acceptance(r):
    r.setting("false")
    race_user, race_token = r.user("race-before")
    phone = "+60123456780"
    SECRETS.extend([phone, phone[1:]])
    path = "/api/auth/request-whatsapp-otp"
    Provider.pause_entered.clear()
    Provider.pause_release.clear()
    r.admin("POST", "/__test/control", {"pause": path})
    before, calls = r.snapshot(), len(Provider.calls)
    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
        future = pool.submit(r.request, "POST", path, {"phone": phone}, race_token)
        check(Provider.pause_entered.wait(5), "transition B paused after entry")
        r.setting("true")
        Provider.pause_release.set()
        blocked(future.result(), "transition B second check blocks OTP persistence/send")
    assert_unchanged(r, before, calls, "transition B")
    r.setting("false")
    # Real active codes ensure the late database checks are reached, rather
    # than merely observing rejection of invalid fixture input.
    code, salt = "314159", "local-transition-salt-917"
    SECRETS.extend([code, salt])
    for table in ["phone_verification_otps", "password_reset_otps"]:
        r.create(table, {"user": r.normal["id"], "phone": r.phone, "status": "active",
                        "otp_hash": hashlib.sha256((salt + ":" + code).encode()).hexdigest(),
                        "otp_salt": salt, "expires_at": "2099-01-01 00:00:00Z", "is_used": False})
    for late_path, body, token in [
        ("/api/auth/verify-whatsapp-otp", {"phone": r.phone, "code": code}, r.token),
        ("/api/auth/confirm-password-reset-whatsapp", {"phone": r.phone, "code": code,
          "password": r.password}, ""),
        ("/api/chat/ask", {"message": "Local paused AI request"}, r.token),
        ("/api/admin/whatsapp/config", {"api_version": "v21.0"}, r.admin_token),
    ]:
        r.setting("false")
        Provider.pause_entered.clear()
        Provider.pause_release.clear()
        r.admin("POST", "/__test/control", {"pause": late_path})
        snapshot, count = r.snapshot(), len(Provider.calls)
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            future = pool.submit(r.request, "POST", late_path, body, token)
            check(Provider.pause_entered.wait(5), "transition B paused " + late_path)
            r.setting("true")
            Provider.pause_release.set()
            blocked(future.result(), "transition B late check " + late_path)
        assert_unchanged(r, snapshot, count, "transition B " + late_path)
    r.setting("false")
    race_user, race_token = r.user("race-after")
    phone = "+60123456781"
    SECRETS.extend([phone, phone[1:]])
    Provider.pause_entered.clear()
    Provider.pause_release.clear()
    Provider.after_send = True
    calls = len(Provider.calls)
    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
        future = pool.submit(r.request, "POST", path, {"phone": phone}, race_token)
        check(Provider.pause_entered.wait(5), "transition C provider accepted before bookkeeping")
        r.setting("true")
        Provider.pause_release.set()
        blocked(future.result(), "transition C bookkeeping blocked after delivery")
    Provider.after_send = False
    rows = [x for x in r.rows("phone_verification_otps") if x["user"] == race_user["id"]]
    check(len(Provider.calls) == calls + 1 and len(rows) == 1 and rows[0]["status"] == "pending"
          and rows[0]["is_used"] == 0, "transition C exactly one delivered but inactive pending OTP")
    OBSERVATIONS["transition_C"] = {"provider_calls": 1, "status": "pending", "is_used": False,
                                   "activation_committed": False, "external_delivery_not_undone": True}
    snapshot, calls = r.snapshot(), len(Provider.calls)
    time.sleep(.2)
    assert_unchanged(r, snapshot, calls, "transition C after request completed")
    r.setting("false")
    code = Provider.calls[-1]["template"]["components"][0]["parameters"][0]["text"]
    SECRETS.append(code)
    result = r.request("POST", "/api/auth/verify-whatsapp-otp", {"phone": phone, "code": code}, race_token)
    check(result[0] == 400, "transition C pending delivered OTP cannot verify after reopen")


def background_acceptance(r):
    r.setting("true")
    expired_ids = {}
    for table in ["phone_verification_otps", "password_reset_otps"]:
        record = r.create(table, {"user": r.normal["id"], "phone": r.phone,
            "otp_hash": "a" * 64, "otp_salt": "b" * 32, "status": "active",
            "expires_at": "2020-01-01 00:00:00Z", "is_used": False})
        expired_ids[table] = record["id"]
    r.create("notification_preferences", {"user": r.normal["id"], "push_enabled": True,
                                          "whatsapp_enabled": True})
    due = r.create("push_broadcasts", {"title": "Local due fixture", "message": "Local due message",
                   "status": "pending", "scheduled_at": "2020-01-01 00:00:00Z"})
    r.create("enrollments", {"user": r.admin_user["id"], "course": r.course["id"],
                             "is_completed": False})
    before, calls = r.snapshot(), len(Provider.calls)
    for job in JOBS:
        r.admin("POST", "/__test/control", {"cron": job})
        assert_unchanged(r, before, calls, "background " + job)
    # Native management intentionally creates the triggering record; assert
    # that no secondary side effects occur from either success callback.
    before = r.snapshot()
    enrollment = r.create("enrollments", {"user": r.normal["id"], "course": r.course["id"]})
    after = r.snapshot()
    check(all(before[t] == after[t] for t in before if t != "enrollments") and
          len(after["enrollments"]) == len(before["enrollments"]) + 1 and len(Provider.calls) == calls,
          "background enrollment create suppresses all secondary effects")
    before = after
    r.patch("enrollments", enrollment["id"], {"is_completed": True,
            "completed_at": datetime.now(timezone.utc).isoformat()})
    after = r.snapshot()
    check(all(before[t] == after[t] for t in before if t != "enrollments") and len(Provider.calls) == calls,
          "background enrollment completion suppresses all secondary effects")
    OBSERVATIONS["background_provider_calls_while_ON"] = len(Provider.calls) - calls
    r.setting("false")
    # Positive controls establish that ON tests were not empty/no-op fixtures.
    for job in JOBS[:2]:
        r.admin("POST", "/__test/control", {"cron": job})
    check(all(next(x for x in r.rows(table) if x["id"] == rid)["status"] == "expired"
              for table, rid in expired_ids.items()), "OFF cleanup positive controls expire eligible OTPs")
    r.admin("POST", "/__test/control", {"cron": "push_reminder_daily"})
    check(len(Provider.calls) == calls + 1, "OFF daily push positive control sends once")
    # Known defect is deliberately not repaired. Exercise it with actual due
    # work so suppression during ON is independently meaningful.
    response = r.request("POST", "/__test/control", {"cron": "push_broadcast_scheduler"}, r.super_token)
    # cronAdd catches/logs handler errors; Job.run() itself returns normally.
    check(response[0] == 200 and len(Provider.calls) == calls + 1 and
          next(x for x in r.rows("push_broadcasts") if x["id"] == due["id"])["status"] == "pending",
          "known OFF scheduler defect retained; no dispatch or bookkeeping")
    OBSERVATIONS["known_scheduler_defect"] = "OFF due-job invocation fails; unchanged, not repaired"


def inspect_logs(r):
    # Stop flushes PocketBase's buffered auxiliary request logs before scan.
    r.stop()
    logs = [(str(p.relative_to(r.base)), p.read_text()) for p in r.base.glob("*.log")]
    with sqlite3.connect("file:" + str(r.data / "auxiliary.db") + "?mode=ro", uri=True) as db:
        logs.append(("data/auxiliary.db:_logs", json.dumps(db.execute("SELECT message,data FROM _logs").fetchall())))
    for table in ["users", "phone_verification_otps", "password_reset_otps"]:
        for row in r.rows(table):
            for field in ["password", "tokenKey", "otp_hash", "otp_salt"]:
                if row.get(field):
                    SECRETS.append(row[field])
    leaks = [name for name, text in logs if any(s and s in text for s in SECRETS)]
    OBSERVATIONS["logs_scanned"] = [name for name, _ in logs]
    OBSERVATIONS["logs_with_sensitive_fixture_matches"] = leaks
    check(not leaks, "logging: no synthetic OTP/password/digest/salt/token/phone/provider-secret leakage")
    filtered = [text.replace("ReferenceError: dispatchBroadcast is not defined", "KNOWN_DEFERRED")
                for _, text in logs]
    check(any("ReferenceError: dispatchBroadcast is not defined" in text for _, text in logs),
          "known deferred scheduler error observed in PocketBase logs")
    check(not any(re.search(r'ReferenceError|TypeError|SyntaxError', text) for text in filtered),
          "runtime logs: no new hook-load or execution type errors")
    check(Provider.unexpected == 0, "network: zero attempts at non-stub provider destinations")


def final_check_gap(r):
    """Observe the remaining TOCTOU gap, without removing either state check.

    This deterministic pause represents descheduling after the final read. It
    is copied-helper instrumentation only, not a production backdoor.
    """
    r.setting("false")
    Provider.pause_entered.clear()
    Provider.pause_release.clear()
    r.admin("POST", "/__test/control", {"afterCheck": True})
    count = len(Provider.calls)
    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
        future = pool.submit(r.request, "POST", "/api/chat/ask", {"message": "Local final-check gap"}, r.token)
        check(Provider.pause_entered.wait(5), "drain probe paused after final state check")
        r.setting("true")
        state = drain_status(r)
        check(state["in_flight_prohibited_operations"] >= 1 and not state["drained"],
              "final-check gap stays authoritatively in-flight after ON")
        check(len(Provider.calls) == count, "drain probe provider quiet at ON acknowledgement")
        Provider.pause_release.set()
        result = future.result()
    check(result[0] == 200 and len(Provider.calls) == count + 1,
          "drain probe demonstrates one pre-existing request can send after ON acknowledgement")
    wait_drained(r)
    OBSERVATIONS["final_check_gap"] = {"preexisting_request": True,
        "provider_calls_after_ON_ack": 1, "checks_removed": False}


def drain_status(r):
    return r.admin("GET", "/api/maintenance/status")


def await_state(predicate, label, seconds=8):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if predicate():
            check(True, label)
            return
        time.sleep(.025)  # condition polling, never a substitute for a drain predicate
    check(False, label)


def wait_zero(r):
    await_state(lambda: drain_status(r)["in_flight_prohibited_operations"] == 0, "authoritative in-flight returns to zero")


def wait_drained(r):
    await_state(lambda: drain_status(r).get("drained") is True, "closed plus zero is authoritatively drained")


def set_hold(r, kind):
    Provider.pause_entered.clear()
    Provider.pause_release.clear()
    r.admin("POST", "/__test/control", {"holdKind": kind})


def admission_acceptance(r):
    wait_drained(r)
    for token in ["", r.token, r.admin_token, r.app_super_token]:
        status(r.request("GET", "/api/maintenance/status", token=token), 403,
               "drain aggregates restricted to native superuser")
    calls = len(Provider.calls)
    webhook(r, "drained")
    check(drain_status(r)["drained"] and len(Provider.calls) == calls, "webhook exception leaves prohibited accounting drained")

    # A: test-only transactional audit captures INSERT ordering relative to the
    # actual setting UPDATE. It is not deployed and stores no user data.
    r.sql("CREATE TABLE _test_admission_audit (id INTEGER PRIMARY KEY, event TEXT, operation TEXT)")
    r.sql("CREATE TRIGGER test_admitted AFTER INSERT ON maintenance_inflight BEGIN "
          "INSERT INTO _test_admission_audit(event,operation) VALUES ('admit',NEW.id); END")
    r.sql("CREATE TRIGGER test_closed AFTER UPDATE ON lms_settings "
          "WHEN NEW.key='maintenance_mode' AND NEW.value='true' AND OLD.value!='true' BEGIN "
          "INSERT INTO _test_admission_audit(event,operation) VALUES ('close',''); END")
    r.setting("false")
    set_hold(r, "http")
    start = threading.Barrier(61)
    count = len(Provider.calls)
    def attempt(_):
        start.wait(10)
        return r.request("POST", "/api/chat/ask", {"message": "Local contention fixture"}, r.token)
    with concurrent.futures.ThreadPoolExecutor(max_workers=60) as pool:
        futures = [pool.submit(attempt, i) for i in range(60)]
        start.wait(10)
        check(Provider.pause_entered.wait(8), "race has admitted work before close")
        r.setting("true")
        state = drain_status(r)
        admitted = state["in_flight_prohibited_operations"]
        check(admitted > 0 and not state["drained"], "all paused admissions visible after close")
        for i in range(10):
            blocked(r.request("POST", "/api/chat/ask", {}, r.token), "post-close admission rejected " + str(i))
        check(drain_status(r)["in_flight_prohibited_operations"] == admitted,
              "no new registration after authoritative close")
        rows = r.sql("SELECT id,event FROM _test_admission_audit ORDER BY id")
        close_id = next(i for i, event in rows if event == "close")
        post_close = sum(event == "admit" and i > close_id for i, event in rows)
        check(post_close == 0 and sum(event == "admit" for _, event in rows) == admitted,
              "transaction audit proves all admitted operations precede close")
        Provider.pause_release.set()
        for f in futures:
            blocked(f.result(), "contended request rejected or safely aborted while counted")
    r.admin("POST", "/__test/control", {"holdKind": ""})
    wait_drained(r)
    check(len(Provider.calls) == count, "race produces no untracked provider effect")
    OBSERVATIONS["admission_race"] = {"concurrent_attempts": 60, "additional_after_close": 10,
        "admitted_before_close": admitted, "rejected_admission": 70 - admitted,
        "maximum_observed_in_flight": admitted, "post_close_admitted": post_close,
        "final_in_flight": 0, "untracked_effects": 0}

    # E: provider-side completion must remain covered, not just the send call's entry.
    r.setting("false")
    Provider.pause_entered.clear()
    Provider.pause_release.clear()
    Provider.after_send = True
    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
        f = pool.submit(r.request, "POST", "/api/chat/ask", {"message": "Local duration fixture"}, r.token)
        check(Provider.pause_entered.wait(5), "provider response paused")
        r.setting("true")
        started = time.monotonic()
        samples = []
        while time.monotonic() - started < 2:
            samples.append(drain_status(r))
            time.sleep(.1)
        check(all(s["in_flight_prohibited_operations"] >= 1 and not s["drained"] for s in samples),
              "provider duration remains counted through every status sample")
        Provider.pause_release.set()
        status(f.result(), 200, "admitted provider work completes")
    Provider.after_send = False
    wait_drained(r)
    OBSERVATIONS["provider_duration"] = {"seconds": 2, "samples": len(samples), "false_drained_samples": 0}

    # F: pause built-in persistence immediately before record-create execution.
    r.setting("false")
    Provider.pause_entered.clear()
    Provider.pause_release.clear()
    r.admin("POST", "/__test/control", {"dbPause": True})
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        f = pool.submit(r.request, "POST", "/api/collections/children/records",
                        {"user": r.normal["id"], "name": "Commit fixture"}, r.token)
        check(Provider.pause_entered.wait(5), "built-in mutation paused near persistence")
        check(drain_status(r)["in_flight_prohibited_operations"] >= 1, "built-in persistence lease visible before commit")
        close = pool.submit(r.setting, "true")
        # A native setting update may wait behind the transaction writer. In
        # either case, the operation must not disappear while still paused.
        state = drain_status(r)
        check(state["in_flight_prohibited_operations"] >= 1 and not state["drained"],
              "DB commit duration cannot report false drained")
        Provider.pause_release.set()
        status(f.result(), 200, "already-admitted built-in mutation completes")
        close.result()
    wait_drained(r)

    # G: legitimate early-return and exception paths release on definite exit.
    r.setting("false")
    for kind in ["return", "throw", "db"]:
        response = r.request("POST", "/__test/failure", {"kind": kind}, r.super_token)
        check(response[0] >= 400, "injected " + kind + " failure observed")
        wait_zero(r)
    status(r.request("POST", "/api/auth/request-whatsapp-otp", {"phone": "invalid"}, r.token),
           400, "validation failure after admission")
    wait_zero(r)
    Provider.error_response = True
    check(r.request("POST", "/api/chat/ask", {"message": "Local provider error"}, r.token)[0] >= 400,
          "provider error after admission")
    Provider.error_response = False
    wait_zero(r)

    # J: concurrently admitted background callbacks are visible independently.
    set_hold(r, "cron")
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        futures = [pool.submit(r.admin, "POST", "/__test/control", {"cron": j}) for j in JOBS[:3]]
        samples = []
        def background_visible():
            samples.append(drain_status(r))
            OBSERVATIONS["background_admission_samples"] = samples
            OBSERVATIONS["background_diagnostics"] = {
                "completed": [f.done() for f in futures],
                "control": r.admin("POST", "/__test/control", {})}
            return samples[-1]["in_flight_prohibited_operations"] >= 3
        await_state(background_visible, "three admitted background jobs visible")
        r.setting("true")
        count = len(Provider.calls)
        for job in JOBS:
            r.admin("POST", "/__test/control", {"cron": job})
        check(drain_status(r)["in_flight_prohibited_operations"] == 3 and not drain_status(r)["drained"],
              "closed admission blocks new jobs while old jobs remain counted")
        Provider.pause_release.set()
        for f in futures:
            f.result()
    r.admin("POST", "/__test/control", {"holdKind": ""})
    wait_drained(r)
    check(len(Provider.calls) == count, "background race no untracked send")
    OBSERVATIONS["background_race"] = {"concurrent_admitted": 3, "new_jobs_after_close": 0,
                                       "final_in_flight": 0, "untracked_sends": 0}

    # Native management bypasses the HTTP gate, but secondary enrollment
    # effects must independently register for BOTH success callback variants.
    enrollment = None
    for operation in ["create", "update"]:
        r.setting("false")
        set_hold(r, "event")
        count = len(Provider.calls)
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            if operation == "create":
                f = pool.submit(r.create, "enrollments", {"user": r.normal["id"], "course": r.course["id"]})
            else:
                f = pool.submit(r.patch, "enrollments", enrollment["id"], {"is_completed": True})
            check(Provider.pause_entered.wait(5), "enrollment " + operation + " callback admitted")
            r.setting("true")
            state = drain_status(r)
            check(state["in_flight_prohibited_operations"] >= 1 and not state["drained"],
                  "enrollment " + operation + " callback remains counted after close")
            Provider.pause_release.set()
            enrollment = f.result()
        r.admin("POST", "/__test/control", {"holdKind": ""})
        wait_drained(r)
        check(len(Provider.calls) == count, "enrollment " + operation + " aborts secondary effects safely")

    # PB's native reset email is asynchronous: its own lease must outlive HTTP.
    r.setting("false")
    Provider.pause_entered.clear()
    Provider.pause_release.clear()
    r.admin("POST", "/__test/control", {"mailPause": True})
    status(r.request("POST", "/api/collections/users/request-password-reset",
                     {"email": "ordinary@example.test"}), 204, "native reset request returns before background mail")
    check(Provider.pause_entered.wait(5), "asynchronous native mail paused")
    r.setting("true")
    check(drain_status(r)["in_flight_prohibited_operations"] >= 1 and not drain_status(r)["drained"],
          "asynchronous mail remains counted after initiating HTTP response")
    Provider.pause_release.set()
    wait_drained(r)

    # I: ambiguity never manufactures drained=true.
    for value in ["invalid", "", "FALSE"]:
        r.setting(value)
        check(not drain_status(r)["state_valid"] and not drain_status(r)["drained"], "invalid control cannot be drained")
    r.admin("DELETE", "/api/collections/lms_settings/records/" + r.setting_id)
    check(not drain_status(r)["drained"], "missing control cannot be drained")
    r.setting_id = r.create("lms_settings", {"key": "maintenance_mode", "value": "true"})["id"]
    dupe = r.create("lms_settings", {"key": "maintenance_mode", "value": "true"})
    check(not drain_status(r)["drained"], "duplicate control cannot be drained")
    r.admin("DELETE", "/api/collections/lms_settings/records/" + dupe["id"])
    r.admin("POST", "/__test/control", {"readFailure": True})
    check(not drain_status(r)["drained"], "unreadable control cannot be drained")
    r.admin("POST", "/__test/control", {"readFailure": False})
    wait_drained(r)
    users_schema = r.admin("GET", "/api/collections/users")
    check(users_schema["otp"]["enabled"] is False, "native email-OTP disabled in current application schema")
    r.admin("PATCH", "/api/collections/users", {"otp": {"enabled": True}})
    check(not drain_status(r)["state_valid"] and not drain_status(r)["drained"],
          "unsupported future native email-OTP configuration cannot certify drain")
    r.admin("PATCH", "/api/collections/users", {"otp": users_schema["otp"]})
    wait_drained(r)

    # H: kill only this run's disposable process with a durable active record.
    r.admin("POST", "/__test/control", {"flushLogs": True})
    r.setting("false")
    set_hold(r, "http")
    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
        f = pool.submit(r.request, "POST", "/api/chat/ask", {"message": "Local crash fixture"}, r.token)
        check(Provider.pause_entered.wait(5), "crash probe admitted")
        r.setting("true")
        ids = [x["id"] for x in r.rows("maintenance_inflight")]
        check(len(ids) == 1 and not drain_status(r)["drained"], "crash lease persisted before termination")
        r.process.kill()
        r.process.wait(timeout=10)
        Provider.pause_release.set()
        try:
            f.result()
        except (OSError, ConnectionError, urllib.error.URLError):
            pass
    r.stop()
    r.start()
    r.super_token, _ = r.login("operator@example.test", collection="_superusers")
    check(drain_status(r)["in_flight_prohibited_operations"] == 1 and not drain_status(r)["drained"],
          "restart preserves active evidence and refuses false drained")
    r.sql("UPDATE maintenance_inflight SET admitted_at='2000-01-01 00:00:00Z'")
    check(not drain_status(r)["drained"], "ancient operation does not expire automatically")
    # This specific process was killed and reaped above; no worker can resume.
    # Explicit synthetic operator recovery is never an automatic production TTL.
    r.admin("DELETE", "/api/collections/maintenance_inflight/records/" + ids[0])
    wait_drained(r)
    OBSERVATIONS["crash_recovery"] = {"stale_records_after_restart": 1, "auto_expired": False,
        "manual_recovery_after_proven_process_exit": True}
    r.setting("false")
    status(r.request("POST", "/api/chat/ask", {"message": "Local reopened"}, r.token), 200, "reopen without restart permits new tracked work")
    wait_zero(r)
    r.setting("true")
    wait_drained(r)
    OBSERVATIONS["operational_drain"] = drain_status(r)


def acceptance(r):
    fixture(r)
    off_acceptance(r)
    on_acceptance(r)
    fail_closed_acceptance(r)
    concurrency_and_bypass(r)
    transition_acceptance(r)
    background_acceptance(r)
    final_check_gap(r)
    admission_acceptance(r)
    inspect_logs(r)


if __name__ == "__main__":
    main()
