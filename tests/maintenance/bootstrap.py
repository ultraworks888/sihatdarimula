#!/usr/bin/env python3
"""Exact, uninstrumented gate-only bootstrap on a fresh synthetic pre-auth DB.

Only this invocation's unique work/maintenance/runs directory is written.
No production data, external providers, or downloaded packages are used.
"""
import argparse
import concurrent.futures
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import socket
import socketserver
import sqlite3
import subprocess
import sys
import threading
import time
import urllib.request
import uuid

sys.dont_write_bytecode = True
import run as common

ROOT = common.ROOT
HOOKS = [
    "maintenance.js", "maintenance.pb.js", "ai_chat.pb.js", "analytics.pb.js",
    "emergency_users_hardening.pb.js", "export.pb.js", "lms_whatsapp.pb.js",
    "meta_whatsapp.pb.js", "push_broadcast.js", "push_broadcast.pb.js", "push_reminders.pb.js",
    "whatsapp.pb.js", "whatsapp_webhook.pb.js",
]
MIGRATIONS = ["1788676088_seed_maintenance_mode_setting_bd01.js",
              "1788845846_create_maintenance_inflight_42a7.js"]
AUTH_PREFIXES = ("1788516108", "1788526407", "1788527376")
QUARANTINED = ("0000000000", "1782898775", "1784882632", "1785841371", "1786721111")
check = common.check
OBS = common.OBSERVATIONS


def save_json(path, value):
    # Artifacts are written once; never truncate an existing result/evidence file.
    with path.open("x") as f:
        json.dump(value, f, indent=2)
        f.write("\n")


class MailSink(socketserver.StreamRequestHandler):
    messages = 0

    def handle(self):
        self.wfile.write(b"220 localhost local-only SMTP sink\r\n")
        while True:
            line = self.rfile.readline()
            if not line:
                return
            verb = line.split(b" ", 1)[0].strip().upper()
            if verb in (b"HELO", b"EHLO"):
                self.wfile.write(b"250 localhost\r\n")
            elif verb == b"DATA":
                self.wfile.write(b"354 end with dot\r\n")
                while True:
                    data = self.rfile.readline()
                    if not data or data == b".\r\n":
                        break
                type(self).messages += 1  # never retain body, addresses, or tokens
                self.wfile.write(b"250 accepted\r\n")
            elif verb == b"QUIT":
                self.wfile.write(b"221 goodbye\r\n")
                return
            else:
                self.wfile.write(b"250 OK\r\n")


class BootstrapRuntime(common.Runtime):
    def runtime_args(self):
        return ["--dir=" + str(self.data), "--hooksDir=" + str(self.hooks),
                "--migrationsDir=" + str(self.migrations), "--hooksWatch=false", "--automigrate=false"]

    def command(self, *args, input=None):
        result = subprocess.run([self.binary, *args, *self.runtime_args()], input=input,
                                capture_output=True, text=True, timeout=40, env=self.env)
        with (self.base / "commands.log").open("a") as log:
            log.write(result.stdout + result.stderr)
        if result.returncode:
            raise RuntimeError("Disposable bootstrap command failed: " + args[0])
        return result.stdout

    def start(self):
        self.log = (self.base / "runtime.log").open("a")
        self.process = subprocess.Popen([self.binary, "serve", "--http=127.0.0.1:" + str(self.port),
                                         *self.runtime_args()], stdout=self.log,
                                        stderr=subprocess.STDOUT, env=self.env)
        for _ in range(100):
            if self.process.poll() is not None:
                raise RuntimeError("Gate profile process failed startup; inspect preserved runtime.log")
            try:
                if self.request("GET", "/api/health")[0] == 200:
                    return
            except OSError:
                pass
            time.sleep(.1)
        raise RuntimeError("Gate profile startup timed out")

    def __init__(self, binary):
        # Deliberately DO NOT call the full-suite constructor: it copies all
        # migrations and instruments hooks, neither of which is allowed here.
        self.binary = str(binary.resolve())
        self.run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-bootstrap-" + uuid.uuid4().hex
        self.base = ROOT / "work/maintenance/runs" / self.run_id
        self.base.mkdir(parents=True, exist_ok=False)
        print("RUN " + str(self.base), flush=True)
        self.data = self.base / "data"
        self.hooks = self.base / "preauth-empty-hooks"
        self.migrations = self.base / "preauth-migrations"
        self.hooks.mkdir()
        self.migrations.mkdir()
        self.process = None
        self.log = None
        self.super_token = ""
        self.password = "Bootstrap-Local-Only-" + uuid.uuid4().hex
        common.SECRETS.append(self.password)
        self.provider = common.ThreadingHTTPServer(("127.0.0.1", 0), common.Provider)
        threading.Thread(target=self.provider.serve_forever, daemon=True).start()
        self.smtp = socketserver.ThreadingTCPServer(("127.0.0.1", 0), MailSink)
        self.smtp.daemon_threads = True
        threading.Thread(target=self.smtp.serve_forever, daemon=True).start()
        stub = "http://127.0.0.1:" + str(self.provider.server_port)
        self.env = dict(os.environ, HTTP_PROXY=stub, HTTPS_PROXY=stub,
                        http_proxy=stub, https_proxy=stub,
                        NO_PROXY="127.0.0.1,localhost", no_proxy="127.0.0.1,localhost")
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            self.port = sock.getsockname()[1]
        self.url = "http://127.0.0.1:" + str(self.port)
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        save_json(self.base / "manifest.json", {
            "run_id": self.run_id, "mode": "local-only-gate-bootstrap",
            "git_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT,
                                               stderr=subprocess.DEVNULL, text=True).strip(),
            "binary_sha256": hashlib.sha256(Path(self.binary).read_bytes()).hexdigest(),
            "hooks_instrumented": False,
        })

    def preauth_proof(self, label):
        fields = [x[1] for x in self.sql("PRAGMA table_info(users)")]
        tables = [x[0] for x in self.sql("SELECT name FROM sqlite_master WHERE type='table'")]
        indexes = [x[0] for x in self.sql("SELECT name FROM sqlite_master WHERE type='index'")]
        history = [x[0] for x in self.sql("SELECT file FROM _migrations ORDER BY file")]
        check(not any(f.startswith(AUTH_PREFIXES + QUARANTINED) for f in history),
              label + ": auth and quarantined migrations never applied")
        check("phone_verified" not in fields and "phone_verified_at" not in fields,
              label + ": no hardened phone fields")
        check("phone_verification_otps" not in tables and "password_reset_otps" not in tables,
              label + ": no hardened OTP collections")
        check("idx_users_verified_phone_unique" not in indexes, label + ": no hardened unique index")
        return {"migration_history": history, "hardened_fields_absent": True,
                "hardened_collections_absent": True, "hardened_index_absent": True}


def state(r):
    return r.admin("GET", "/api/maintenance/status")


def drained(r, label):
    actual = state(r)
    check(actual == {"state_valid": True, "maintenance_active": True,
          "admission_closed": True, "in_flight_prohibited_operations": 0, "drained": True}, label)
    return actual


def no_provider():
    check(common.Provider.unexpected == 0 and not common.Provider.calls and MailSink.messages == 0,
          "zero outbound HTTP/provider/SMTP activity")


def verify_payload(r, manifest):
    check(sorted(p.name for p in r.hooks.iterdir()) == sorted(HOOKS), "exact thirteen-hook inventory; no extra hooks")
    check(sorted(p.name for p in r.migrations.iterdir()) == sorted(MIGRATIONS), "exact two-migration startup profile")
    for entry in manifest:
        path = r.base / "payload" / entry["path"]
        check(hashlib.sha256(path.read_bytes()).hexdigest() == entry["sha256"] ==
              hashlib.sha256((ROOT / entry["path"]).read_bytes()).hexdigest(),
              "payload SHA-256 verified: " + entry["path"])


def prepare(r):
    check("0.29.3" in r.command("--version"), "real PocketBase v0.29.3")
    history_sources = sorted(p for p in (ROOT / "pb_migrations").glob("*.js")
                             if p.name[:10].isdigit() and p.name[:10] < "1788516108"
                             and not p.name.startswith(QUARANTINED))
    check(len(history_sources) == 26, "pre-auth construction: exactly 26 safe historical migrations")
    for p in history_sources:
        shutil.copyfile(p, r.migrations / p.name)
    save_json(r.base / "preauth-source-manifest.json", [
        {"path": "pb_migrations/" + p.name, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
        for p in history_sources])
    r.command("migrate", "up")
    OBS["preauth_schema_before"] = r.preauth_proof("constructed pre-auth schema")
    r.command("superuser", "create", "operator@example.test", r.password)
    r.start()
    r.super_token, _ = r.login("operator@example.test", collection="_superusers")
    r.admin("PATCH", "/api/settings", {"smtp": {"enabled": True, "host": "127.0.0.1",
            "port": r.smtp.server_address[1], "tls": False, "authMethod": "PLAIN",
            "username": "", "password": ""}, "meta": {"appURL": r.url}})
    # Synthetic equivalents of existing pre-auth records. No hooks are loaded
    # in this fixture setup process, so no outbound application callbacks run.
    r.normal, r.token = r.user("ordinary")
    r.admin_user, r.admin_token = r.user("app-admin", role="admin")
    r.super_user, r.app_super_token = r.user("app-superadmin", role="superadmin")
    r.child = r.create("children", {"user": r.normal["id"], "name": "Bootstrap child"})
    r.setting_id = r.create("lms_settings", {"key": "maintenance_mode", "value": "false"})["id"]
    for key, value in {"onesignal_app_id": "local-app", "onesignal_api_key": "local-secret-" + uuid.uuid4().hex,
                       "whatsapp_phone_number_id": "local-phone", "whatsapp_access_token": "local-secret-" + uuid.uuid4().hex}.items():
        r.upsert_setting(key, value)
        if "key" in key or "token" in key:
            common.SECRETS.append(value)
    r.create("notification_preferences", {"user": r.normal["id"], "push_enabled": True})
    r.create("push_broadcasts", {"title": "Due bootstrap fixture", "message": "Local fixture",
             "status": "pending", "scheduled_at": "2020-01-01 00:00:00Z"})
    r.admin("POST", "/api/collections", {"name": "whatsapp_server_secrets", "type": "base",
            "listRule": None, "viewRule": None, "createRule": None, "updateRule": None, "deleteRule": None,
            "fields": [{"name": "key", "type": "text"}, {"name": "value", "type": "text"}]})
    r.webhook_secret = "local-webhook-" + uuid.uuid4().hex
    common.SECRETS.append(r.webhook_secret)
    r.create("whatsapp_server_secrets", {"key": "wa_internal_forward_secret", "value": r.webhook_secret})
    r.setting("true")
    check(r.admin("GET", "/api/collections/lms_settings/records/" + r.setting_id)["value"] == "true",
          "exact true persisted through native administration before stop")
    old_pid = r.process.pid
    r.stop()
    check(r.process.poll() is not None, "old process exited and was reaped")
    try:
        os.kill(old_pid, 0)
        gone = False
    except ProcessLookupError:
        gone = True
    check(gone, "OS confirms old PID absent")
    with socket.socket() as s:
        check(s.connect_ex(("127.0.0.1", r.port)) != 0, "old listener closed before payload installation")
    check(r.sql("SELECT value FROM lms_settings WHERE key='maintenance_mode'") == [("true",)],
          "stopped database contains exact durable true")
    # Model the supplied production history without importing/replaying the
    # unauthorized source: the setting effect already exists, filename is marked.
    r.sql("INSERT INTO _migrations(file,applied) VALUES (?,?)", (MIGRATIONS[0], int(time.time() * 1000000)))
    OBS["existing_1788676088_history"] = "synthetic applied-filename fixture; existing true effect, no production source imported"
    r.hooks = r.base / "payload/pb_hooks"
    r.migrations = r.base / "payload/pb_migrations"
    r.hooks.mkdir(parents=True)
    r.migrations.mkdir()
    for f in MIGRATIONS:
        shutil.copyfile(ROOT / "pb_migrations" / f, r.migrations / f)
    r.command("migrate", "up")  # empty hook directory; only two gate files visible
    check(r.sql("SELECT value FROM lms_settings WHERE key='maintenance_mode'") == [("true",)],
          "gate migrations preserve existing true")
    check(len(r.sql("SELECT file FROM _migrations WHERE file=?", (MIGRATIONS[1],))) == 1,
          "coordination migration applied exactly once")
    r.command("migrate", "up")
    check(r.sql("SELECT count(*) FROM maintenance_inflight") == [(0,)], "repeated gate UP remains empty/idempotent")
    for f in HOOKS:
        shutil.copyfile(ROOT / "pb_hooks" / f, r.hooks / f)
    manifest = []
    for directory, files in [("pb_hooks", HOOKS), ("pb_migrations", MIGRATIONS)]:
        for name in files:
            role = "migration" if directory == "pb_migrations" else (
                "shared helper" if name in ("maintenance.js", "push_broadcast.js") else
                "maintenance hook" if name == "maintenance.pb.js" else "existing guarded hook")
            rel = directory + "/" + name
            manifest.append({"path": rel, "sha256": hashlib.sha256((ROOT / rel).read_bytes()).hexdigest(), "role": role})
    save_json(r.base / "payload-manifest.json", manifest)
    verify_payload(r, manifest)
    OBS["preauth_schema_before_new_start"] = r.preauth_proof("before gate-only start")
    r.start()
    check(r.process.pid != old_pid, "new process has distinct PID")
    listening = subprocess.run(["lsof", "-nP", "-a", "-p", str(r.process.pid),
                               "-iTCP:" + str(r.port), "-sTCP:LISTEN", "-t"],
                              capture_output=True, text=True, timeout=10)
    check(listening.returncode == 0 and str(r.process.pid) in listening.stdout.split(),
          "OS listener belongs to new PocketBase PID")
    OBS["lifecycle"] = {"old_pid": old_pid, "old_pid_absent": gone,
        "old_listener_closed": True, "new_pid": r.process.pid, "listening_pid": r.process.pid,
        "listen_address": "127.0.0.1:" + str(r.port), "hooks_watch": False,
        "profile_start_count": 1, "in_process_restart": False}
    OBS["immediate_startup_status"] = drained(r, "immediate startup: valid true, closed, zero, drained")
    return manifest


def acceptance(r):
    before = r.snapshot()
    for label, token in [("anonymous", ""), ("user", r.token), ("admin", r.admin_token), ("app-superadmin", r.app_super_token)]:
        common.status(r.request("GET", "/api/maintenance/status", token=token), 403, "status rejects " + label)
    requests = [
        ("POST", "/api/collections/children/records", {"user": r.normal["id"], "name": "Blocked"}, r.token),
        ("PATCH", "/api/collections/children/records/" + r.child["id"], {"name": "Blocked"}, r.token),
        ("DELETE", "/api/collections/children/records/" + r.child["id"], None, r.token),
        ("POST", "/api/collections/users/records", {}, ""),
        ("POST", "/api/collections/users/auth-with-password", {"identity": "ordinary@example.test", "password": r.password}, ""),
        ("POST", "/api/collections/users/auth-refresh", {}, r.token),
        ("POST", "/api/batch", {"requests": []}, r.token),
    ] + [(m, p, {}, r.admin_token) for m, p in common.MUTATIONS if not p.startswith("/api/auth/")]
    responses = []
    for m, p, body, token in requests:
        response = r.request(m, p, body, token)
        common.blocked(response, "from-start blocked " + m + " " + p)
        responses.append({"method": m, "path": re.sub(r"/records/[a-z0-9]+$", "/records/{fixture-id}", p), "status": response[0]})
    check(r.snapshot() == before, "blocked requests leave all application/auth tables unchanged")
    no_provider()
    with concurrent.futures.ThreadPoolExecutor(max_workers=20) as pool:
        for result in pool.map(lambda _: r.request("POST", "/api/chat/ask", {}, r.token), range(40)):
            common.blocked(result, "concurrent bootstrap request blocked")
    check(r.snapshot() == before, "concurrent blocked requests leave application/auth state unchanged")
    drained(r, "drain remains trustworthy after blocked concurrency")
    for _, path in [x for x in common.MUTATIONS if x[1].startswith("/api/auth/")]:
        common.status(r.request("POST", path, {}, r.token), 404, "expected absent hardened auth route " + path)
    check(r.snapshot() == before, "absent auth routes have no state effects")
    no_provider()
    common.webhook(r, "bootstrap")
    after = r.snapshot()
    check(all(after[t] == before[t] for t in before if t != "whatsapp_webhook_events"),
          "authenticated webhook changes only its allowed ingestion table")
    drained(r, "webhook leaves prohibited accounting drained")
    jobs = r.admin("GET", "/api/crons")
    custom_jobs = sorted(j["id"] for j in jobs if not j["id"].startswith("__pb"))
    check(custom_jobs == ["push_broadcast_scheduler", "push_reminder_daily"],
          "only two gate-profile custom cron jobs registered; no auth cleanup jobs")
    for job in custom_jobs:
        common.status(r.request("POST", "/api/crons/" + job, token=r.super_token), 204, "native cron invocation " + job)
    # Observation interval checks stability; never used as the drain predicate.
    samples = []
    for _ in range(10):
        samples.append(drained(r, "closed startup background observation"))
        time.sleep(.1)
    check(r.snapshot() == after, "due background fixtures produce no scheduled mutations")
    no_provider()
    OBS["public_mutations"] = responses
    OBS["auth_route_absence"] = {p: 404 for _, p in common.MUTATIONS if p.startswith("/api/auth/")}
    OBS["background"] = {"custom_jobs": custom_jobs, "status_samples": len(samples),
                         "prohibited_mutations": 0, "provider_attempts": 0,
                         "known_defect": "source unchanged; not exercised OFF in gate-only profile"}
    # Alter only synthetic operator control records; never reopen admission.
    for value in ["TRUE", "invalid", "", " false "]:
        r.setting(value)
        check(not state(r)["state_valid"] and not state(r)["drained"], "malformed state cannot certify drain")
        common.blocked(r.request("POST", "/api/chat/ask", {}, r.token), "malformed state fails closed")
    r.setting("true")
    duplicate = r.create("lms_settings", {"key": "maintenance_mode", "value": "true"})
    check(not state(r)["drained"], "duplicate control cannot certify drain")
    common.blocked(r.request("POST", "/api/chat/ask", {}, r.token), "duplicate control blocks mutation")
    r.admin("DELETE", "/api/collections/lms_settings/records/" + duplicate["id"])
    r.admin("DELETE", "/api/collections/lms_settings/records/" + r.setting_id)
    check(not state(r)["drained"], "missing control cannot certify drain")
    common.blocked(r.request("POST", "/api/chat/ask", {}, r.token), "missing control blocks mutation")
    r.setting_id = r.create("lms_settings", {"key": "maintenance_mode", "value": "true"})["id"]
    # A malformed coordination collection is ambiguous even with an empty table.
    schema = r.admin("GET", "/api/collections/maintenance_inflight")
    r.admin("PATCH", "/api/collections/maintenance_inflight", {"listRule": ""})
    check(not state(r)["drained"], "unlocked coordination schema cannot certify drain")
    common.blocked(r.request("POST", "/api/chat/ask", {}, r.token), "unlocked coordination fails closed")
    r.admin("PATCH", "/api/collections/maintenance_inflight", {"listRule": schema["listRule"]})
    r.admin("PATCH", "/api/collections/maintenance_inflight", {"name": "local_missing_coordination"})
    check(not state(r)["drained"], "missing coordination collection cannot certify drain")
    common.blocked(r.request("POST", "/api/chat/ask", {}, r.token), "missing coordination collection fails closed")
    r.admin("PATCH", "/api/collections/local_missing_coordination", {"name": "maintenance_inflight"})
    OBS["final_status"] = drained(r, "final gate-only status remains closed and drained")
    OBS["preauth_schema_after"] = r.preauth_proof("after all gate-only checks")
    check(r.process.poll() is None, "gate-only process remains stable")
    no_provider()


def logs(r):
    r.stop()
    texts = [p.read_text() for p in r.base.glob("*.log")]
    with sqlite3.connect("file:" + str(r.data / "auxiliary.db") + "?mode=ro", uri=True) as db:
        texts.append(json.dumps(db.execute("SELECT message,data FROM _logs").fetchall()))
    check(not any(re.search(r"ReferenceError|TypeError|SyntaxError|failed to execute.*pb\.js|no such (table|column)", t, re.I)
                  for t in texts), "no hook-load, missing-schema, or JS execution errors")
    check(not any(secret and secret in t for secret in common.SECRETS for t in texts),
          "no fixture password, token, or provider-secret leakage in logs")
    OBS["logs"] = {"files": ["commands.log", "runtime.log", "data/auxiliary.db:_logs"],
                   "schema_or_hook_errors": 0, "sensitive_fixture_matches": 0}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", type=Path, required=True)
    args = parser.parse_args()
    runtime = None
    outcome = 1
    try:
        runtime = BootstrapRuntime(args.binary)
        manifest = prepare(runtime)
        acceptance(runtime)
        verify_payload(runtime, manifest)
        logs(runtime)
        OBS["verdict"] = "PASS"
        outcome = 0
    except Exception as error:
        OBS["verdict"] = "BLOCKED"
        OBS["failure"] = str(error)
        print("BLOCKED: " + str(error), flush=True)
    finally:
        if runtime:
            runtime.stop()
            runtime.provider.shutdown()
            runtime.smtp.shutdown()
            save_json(runtime.base / "results.json", {"passed": common.RESULTS, "observations": OBS})
    return outcome


if __name__ == "__main__":
    raise SystemExit(main())
