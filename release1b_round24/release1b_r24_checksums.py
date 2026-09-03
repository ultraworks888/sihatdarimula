#!/usr/bin/env python3
"""
release1b_r24_checksums.py — Round 24 Integrity Tool

D24-12 / D23-11 retained:
  - Generation refuses to overwrite populated baseline without --replace.
  - Verifier rejects symlinks and non-regular files.
  - Checksum limitation remains an unresolved provenance issue.
  - Filename in ARTIFACTS list matches delivered filenames exactly.

UNRESOLVED PROVENANCE LIMITATION:
  SHA-256 cannot be pre-computed by the AI delivery environment.
  The operator must run --generate after receipt to establish the baseline.
  This is not a corrected defect; it is an acknowledged delivery constraint.

THREAT MODEL:
  This script and release1b_r24_checksums.sha256 are themselves artifacts
  that could be tampered with. Record their own integrity separately:
    shasum -a 256 release1b_r24_checksums.py release1b_r24_checksums.sha256
"""

import sys
import os
import hashlib
import argparse
import stat


ARTIFACTS = [
    "release1b_cp0.zsh",
    "release1b_otp_test_adapter.pb.js",
    "release1b_cp0_manifest.json",
    "release1b_schema_manifest.json",
    "release1b_hook_manifest.json",
    "release1b_test_manifest.json",
    "release1b_operator_instructions.md",
    "release1b_round24_review.md",
]

CHECKSUMS_FILE = "release1b_r24_checksums.sha256"
PLACEHOLDER_MARKERS = ["SHA256_COMPUTE_REQUIRED", "PLACEHOLDER", "COMPUTE_REQUIRED"]


def _is_regular_file(path):
    try:
        lstat = os.lstat(path)
    except OSError:
        return False, "lstat failed"
    if stat.S_ISLNK(lstat.st_mode):
        return False, "is a symlink"
    if not stat.S_ISREG(lstat.st_mode):
        return False, f"not a regular file (mode={oct(stat.S_IFMT(lstat.st_mode))})"
    return True, "ok"


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            block = f.read(65536)
            if not block:
                break
            h.update(block)
    return h.hexdigest()


def byte_count(path):
    return os.path.getsize(path)


def _checksums_is_populated(checksums_path):
    if not os.path.isfile(checksums_path):
        return False
    with open(checksums_path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            for marker in PLACEHOLDER_MARKERS:
                if marker in line:
                    return False
            parts = line.split("  ", 1)
            if len(parts) == 2 and len(parts[0]) == 64:
                return True
    return False


def generate(script_dir, replace=False):
    out_path = os.path.join(script_dir, CHECKSUMS_FILE)

    if _checksums_is_populated(out_path) and not replace:
        print(
            f"ERROR: {CHECKSUMS_FILE} already contains a populated baseline.",
            file=sys.stderr,
        )
        print("Use --replace to explicitly authorize overwriting it.", file=sys.stderr)
        sys.exit(2)

    lines = []
    for name in ARTIFACTS:
        full = os.path.join(script_dir, name)
        ok, reason = _is_regular_file(full)
        if not ok:
            print(f"ERROR: artifact {name!r}: {reason}", file=sys.stderr)
            sys.exit(1)
        digest = sha256_file(full)
        size = byte_count(full)
        lines.append(f"{digest}  {name}")
        print(f"  {digest}  {size:>9}  {name}")

    tmp = out_path + ".gen_tmp"
    with open(tmp, "w") as f:
        f.write("\n".join(lines) + "\n")
    os.chmod(tmp, 0o600)
    os.replace(tmp, out_path)
    print(f"\nWrote {len(lines)} entries to: {CHECKSUMS_FILE}")
    print("\nRecord this tool's own integrity separately (out-of-band):")
    me = os.path.join(script_dir, "release1b_r24_checksums.py")
    ok, reason = _is_regular_file(me)
    if ok:
        self_digest = sha256_file(me)
        self_size = byte_count(me)
        print(f"  release1b_r24_checksums.py:    sha256={self_digest}  bytes={self_size}")
    cs_ok, _ = _is_regular_file(out_path)
    if cs_ok:
        cs_digest = sha256_file(out_path)
        cs_size = byte_count(out_path)
        print(f"  {CHECKSUMS_FILE}: sha256={cs_digest}  bytes={cs_size}")


def verify(script_dir):
    checksums_path = os.path.join(script_dir, CHECKSUMS_FILE)

    ok, reason = _is_regular_file(checksums_path)
    if not ok:
        print(f"ERROR: {CHECKSUMS_FILE}: {reason}", file=sys.stderr)
        sys.exit(1)

    if not os.path.isfile(checksums_path):
        print(f"ERROR: checksums file not found: {CHECKSUMS_FILE}", file=sys.stderr)
        sys.exit(1)

    with open(checksums_path) as f:
        raw_lines = [l.rstrip("\n") for l in f if l.strip() and not l.startswith("#")]

    if not raw_lines:
        print("ERROR: checksums file is empty.", file=sys.stderr)
        sys.exit(1)

    for line in raw_lines:
        for marker in PLACEHOLDER_MARKERS:
            if marker in line:
                print(
                    f"ERROR: checksums file contains placeholder '{marker}'.",
                    file=sys.stderr,
                )
                sys.exit(1)

    entries = {}
    for line in raw_lines:
        parts = line.split("  ", 1)
        if len(parts) != 2:
            print(f"ERROR: malformed line: {line!r}", file=sys.stderr)
            sys.exit(1)
        digest, name = parts[0].strip(), parts[1].strip()
        if len(digest) != 64 or not all(c in "0123456789abcdef" for c in digest):
            print(f"ERROR: invalid SHA-256 digest for {name!r}", file=sys.stderr)
            sys.exit(1)
        if name in entries:
            print(f"ERROR: duplicate entry for {name!r}", file=sys.stderr)
            sys.exit(1)
        entries[name] = digest

    expected_set = set(ARTIFACTS)
    actual_set = set(entries.keys())
    missing = expected_set - actual_set
    extra = actual_set - expected_set
    if missing:
        print(f"ERROR: missing artifacts in checksums: {missing}", file=sys.stderr)
        sys.exit(1)
    if extra:
        print(f"ERROR: unexpected entries in checksums: {extra}", file=sys.stderr)
        sys.exit(1)

    failures = []
    for name in ARTIFACTS:
        full = os.path.join(script_dir, name)
        expected_digest = entries[name]

        ok, reason = _is_regular_file(full)
        if not ok:
            print(f"  REJECT   {name} ({reason})", file=sys.stderr)
            failures.append(name)
            continue

        if not os.path.isfile(full):
            print(f"  MISSING  {name}", file=sys.stderr)
            failures.append(name)
            continue

        actual_digest = sha256_file(full)
        if actual_digest == expected_digest:
            print(f"  OK       {name}")
        else:
            print(f"  FAIL     {name}", file=sys.stderr)
            failures.append(name)

    if failures:
        print(f"\nVERIFICATION FAILED: {len(failures)} artifact(s) failed.", file=sys.stderr)
        sys.exit(1)
    print(f"\nVERIFICATION PASSED: all {len(ARTIFACTS)} artifacts OK.")


def main():
    parser = argparse.ArgumentParser(description="R24 Integrity Tool")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--generate", action="store_true")
    group.add_argument("--verify", action="store_true")
    parser.add_argument(
        "--replace",
        action="store_true",
        help="Allow --generate to overwrite an existing populated baseline.",
    )
    args = parser.parse_args()
    if args.replace and not args.generate:
        parser.error("--replace is only valid with --generate")
    script_dir = os.path.dirname(os.path.realpath(__file__))
    if args.generate:
        generate(script_dir, replace=args.replace)
    elif args.verify:
        verify(script_dir)


if __name__ == "__main__":
    main()
