#!/usr/bin/env python3
"""
release1b_r22_checksums.py — Round 22 Integrity Tool
Non-recursive: this script covers the other 8 artifacts; its own
integrity is provided separately in the delivery message.

USAGE:
  Generate checksums file from current artifacts:
    python3 release1b_r22_checksums.py --generate

  Verify artifacts against checksums file:
    python3 release1b_r22_checksums.py --verify

EXIT CODES:
  0 = all verified OK
  1 = verification failure (mismatch, missing, extra, or placeholder)
  2 = usage error

CHECKSUMS FILE FORMAT (shasum -a 256 --check compatible):
  <sha256hex>  <filename>

CONSTRAINT NOTE:
  SHA-256 values cannot be pre-computed by the AI tool environment.
  Run --generate once after receiving the package. The resulting
  release1b_r22_checksums.sha256 file is the integrity baseline.
  Use --verify for all subsequent checks.
"""

import sys
import os
import hashlib
import argparse

ARTIFACTS = [
    "release1b_cp0.zsh",
    "release1b_otp_test_adapter.pb.js",
    "release1b_cp0_manifest.json",
    "release1b_schema_manifest.json",
    "release1b_hook_manifest.json",
    "release1b_test_manifest.json",
    "release1b_operator_instructions.md",
    "release1b_round22_review.md",
]

CHECKSUMS_FILE = "release1b_r22_checksums.sha256"
PLACEHOLDER = "SHA256_COMPUTE_REQUIRED"


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


def generate(script_dir):
    out_path = os.path.join(script_dir, CHECKSUMS_FILE)
    lines = []
    for name in ARTIFACTS:
        full = os.path.join(script_dir, name)
        if not os.path.isfile(full):
            print(f"ERROR: artifact not found: {name}", file=sys.stderr)
            sys.exit(1)
        digest = sha256_file(full)
        size = byte_count(full)
        lines.append(f"{digest}  {name}")
        print(f"  {digest}  {size:>8}  {name}")

    tmp = out_path + ".gen_tmp"
    with open(tmp, "w") as f:
        f.write("\n".join(lines) + "\n")
    os.chmod(tmp, 0o600)
    os.replace(tmp, out_path)
    print(f"\nWrote {len(lines)} entries to: {CHECKSUMS_FILE}")
    print(f"\nRecord this file's own integrity separately:")
    self_digest = sha256_file(os.path.join(script_dir, "release1b_r22_checksums.py"))
    self_size = byte_count(os.path.join(script_dir, "release1b_r22_checksums.py"))
    print(f"  release1b_r22_checksums.py: sha256={self_digest}  bytes={self_size}")


def verify(script_dir):
    checksums_path = os.path.join(script_dir, CHECKSUMS_FILE)
    if not os.path.isfile(checksums_path):
        print(f"ERROR: checksums file not found: {CHECKSUMS_FILE}", file=sys.stderr)
        print("Run --generate first.", file=sys.stderr)
        sys.exit(1)

    with open(checksums_path) as f:
        raw_lines = [l.rstrip("\n") for l in f if l.strip() and not l.startswith("#")]

    if not raw_lines:
        print("ERROR: checksums file is empty.", file=sys.stderr)
        sys.exit(1)

    # Fail closed on any placeholder.
    for line in raw_lines:
        if PLACEHOLDER in line:
            print(f"ERROR: checksums file contains placeholder value.", file=sys.stderr)
            print("Run --generate to populate.", file=sys.stderr)
            sys.exit(1)

    # Parse entries.
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

    # Check coverage: must cover exactly ARTIFACTS, no more, no less.
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

    # Verify each artifact.
    failures = []
    for name in ARTIFACTS:
        full = os.path.join(script_dir, name)
        expected_digest = entries[name]
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
    parser = argparse.ArgumentParser(description="R22 Integrity Tool")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--generate", action="store_true")
    group.add_argument("--verify", action="store_true")
    args = parser.parse_args()

    script_dir = os.path.dirname(os.path.realpath(__file__))

    if args.generate:
        generate(script_dir)
    elif args.verify:
        verify(script_dir)


if __name__ == "__main__":
    main()
