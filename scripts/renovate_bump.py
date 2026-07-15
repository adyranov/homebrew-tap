#!/usr/bin/env python3
"""Renovate bump workflow driver — stdlib only.

Subcommands
-----------
validate-pr  -- Validate PR diff, formula structure, and canary version.
apply-bump   -- Restore base formulae and run trusted bump script.
stage        -- Verify and stage bumped formulae.
commit-push  -- Commit and push with force-with-lease (App token).

Security
--------
- Called from a trusted copy in $RUNNER_TEMP (copied from base SHA).
- Does NOT import workspace modules or execute PR-provided scripts.
- Consumes trusted Ruby --list-formulae to avoid a third allowlist in Python.
- Pipes canary formula bytes to trusted Ruby --extract-version (Ripper AST
  parser) — never evaluates PR Ruby.
- App token arrives only through TOKEN env; never CLI args, logs, or URLs.
- Uses GIT_ASKPASS for credential injection — token never in remote URL.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile

# ---------------------------------------------------------------------------
# Constants / patterns
# ---------------------------------------------------------------------------

VERSION_RE = re.compile(r"^v(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$")
SHA_RE = re.compile(r"^[0-9a-f]{40}$")
NAME_RE = re.compile(r"^[a-zA-Z][a-zA-Z0-9_-]*$")
REPO_RE = re.compile(r"^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _die(msg):
    print(f"Error: {msg}", file=sys.stderr)
    sys.exit(1)


def _run(cmd, **kwargs):
    """Run a command and return CompletedProcess.  Die on non-zero."""
    kwargs.setdefault("capture_output", True)
    kwargs.setdefault("text", True)
    r = subprocess.run(cmd, **kwargs)
    if r.returncode != 0:
        err = r.stderr.strip()
        if isinstance(err, bytes):
            err = err.decode("utf-8", errors="replace")
        _die(f"Command failed: {' '.join(cmd)}\n{err}")
    return r


def _run_nofail(cmd, **kwargs):
    """Run and return CompletedProcess (caller handles errors)."""
    kwargs.setdefault("capture_output", True)
    kwargs.setdefault("text", True)
    return subprocess.run(cmd, **kwargs)


def _write_github_output(path: str | None, records: dict[str, str]):
    """Append KEY=VALUE lines to *path* (GITHUB_OUTPUT file)."""
    if path is None:
        return
    with open(path, "a") as f:
        for k, v in records.items():
            f.write(f"{k}={v}\n")


# ---------------------------------------------------------------------------
# Trusted Ruby script interaction
# ---------------------------------------------------------------------------


def _get_formulae(bump_script: str) -> list[str]:
    """Run trusted Ruby *bump_script* --list-formulae, validate output.

    Returns sorted list of safe, unique formula names.
    """
    r = _run_nofail(["ruby", bump_script, "--list-formulae"])
    if r.returncode != 0:
        _die(f"Failed to list formulae from {bump_script}: {r.stderr.strip()}")
    names = [ln.strip() for ln in r.stdout.strip().split("\n") if ln.strip()]
    if not names:
        _die("Empty formula list from --list-formulae")
    seen: set[str] = set()
    for n in names:
        if not NAME_RE.match(n):
            _die(f"Unsafe formula name {n!r} from {bump_script}")
        if n in seen:
            _die(f"Duplicate formula name {n!r} from {bump_script}")
        seen.add(n)
    return sorted(seen)


def _formula_paths(formulae: list[str]) -> list[str]:
    """Map formula names to git workspace paths."""
    return [f"Formula/{n}.rb" for n in formulae]


def _extract_version(bump_script: str, data: bytes) -> str:
    """Pipe *data* (canary formula bytes) to trusted Ruby --extract-version."""
    r = _run_nofail(
        ["ruby", bump_script, "--extract-version"],
        input=data,
        text=False,
    )
    if r.returncode != 0:
        err = r.stderr.decode("utf-8", errors="replace").strip()
        _die(f"Canary version extraction failed:\n{err}")
    ver = r.stdout.decode("utf-8", errors="replace").strip()
    if not VERSION_RE.match(ver):
        _die(f"Extracted version {ver!r} does not match expected format")
    return ver


# ---------------------------------------------------------------------------
# Subcommand: validate-pr
# ---------------------------------------------------------------------------


def cmd_validate_pr(args: argparse.Namespace):
    # Validate SHA format first
    for label, val in [("--base-sha", args.base_sha), ("--head-sha", args.head_sha)]:
        if not SHA_RE.match(val):
            _die(f"{label}: invalid SHA {val!r}")

    formulae = _get_formulae(args.bump_script)
    expected_paths = _formula_paths(formulae)

    # 1. Every manifest file must exist in HEAD_SHA with a regular-file mode.
    for path in expected_paths:
        r = _run(["git", "ls-tree", args.head_sha, path])
        if not r.stdout.strip():
            _die(f"Missing manifest file in HEAD: {path}")
        parts = r.stdout.strip().split()
        mode = parts[0] if parts else ""
        if mode not in ("100644", "100755"):
            _die(f"Manifest file {path} has unexpected git mode {mode}")

    # 2. Parse NUL-delimited diff.  Accept only M entries for manifest paths.
    r = _run(
        [
            "git",
            "diff",
            "--name-status",
            "-z",
            "--no-renames",
            args.base_sha,
            args.head_sha,
        ],
        text=False,
    )

    modified = set()
    parts = r.stdout.split(b"\0")
    i = 0
    while i < len(parts) - 1:
        status = parts[i].decode("utf-8", errors="replace")
        path = parts[i + 1].decode("utf-8", errors="replace")
        i += 2
        if not status or not path:
            continue
        if status != "M":
            _die(f"Non-modification status {status!r} for {path}")
        if path not in set(expected_paths):
            _die(f"Changed path {path!r} is not a manifest path")
        modified.add(path)

    if not modified:
        _die("No allowed modifications in PR diff")

    # 3. Extract + validate canary version (never eval PR Ruby).
    canary = _run(["git", "show", f"{args.head_sha}:Formula/llama-cpp.rb"])
    version = _extract_version(args.bump_script, canary.stdout.encode())

    _write_github_output(
        args.github_output,
        {
            "validation_result": "pass",
            "version": version,
        },
    )


# ---------------------------------------------------------------------------
# Subcommand: apply-bump
# ---------------------------------------------------------------------------


def cmd_apply_bump(args: argparse.Namespace):
    if not SHA_RE.match(args.base_sha):
        _die(f"--base-sha: invalid SHA {args.base_sha!r}")
    if not VERSION_RE.match(args.version):
        _die(f"--version: invalid version {args.version!r}")

    formulae = _get_formulae(args.bump_script)
    paths = _formula_paths(formulae)

    # Restore from base SHA — discard working-tree changes.
    for p in paths:
        _run(["git", "restore", "--source", args.base_sha, "--worktree", "--", p])

    # Run trusted Ruby bump script with inherited GITHUB_TOKEN.
    env = os.environ.copy()
    env["FORMULA_DIR"] = args.formula_dir

    r = _run_nofail(["ruby", args.bump_script, args.version], env=env)
    if r.returncode != 0:
        _die(f"Bump script failed (exit {r.returncode}):\n{r.stderr.strip()}")
    if r.stdout:
        sys.stdout.write(r.stdout)
    if r.stderr:
        sys.stderr.write(r.stderr)


# ---------------------------------------------------------------------------
# Subcommand: stage
# ---------------------------------------------------------------------------


def cmd_stage(args: argparse.Namespace):
    formulae = _get_formulae(args.bump_script)
    expected_paths = _formula_paths(formulae)

    # Reject any pre-existing staged changes.
    r = _run_nofail(["git", "diff", "--cached", "--quiet"])
    if r.returncode != 0:
        _die("Pre-existing staged changes detected")

    # Reject untracked files.
    r = _run(["git", "ls-files", "--others", "--exclude-standard"])
    if r.stdout.strip():
        _die(f"Unexpected untracked files:\n{r.stdout.strip()}")

    # Check working-tree diff.
    r = _run(["git", "diff", "--name-status"])
    changes = r.stdout.strip()

    if not changes:
        _write_github_output(args.github_output, {"has_changes": "false"})
        return

    changed_set: set[str] = set()
    for line in changes.split("\n"):
        line = line.strip()
        if not line:
            continue
        parts = line.split("\t", 1)
        if len(parts) != 2:
            _die(f"Cannot parse diff line: {line!r}")
        status, path = parts
        if status != "M":
            _die(f"Unexpected change status {status!r} for {path}")
        if path not in expected_paths:
            _die(f"Changed path {path!r} is not a manifest path")
        changed_set.add(path)

    if changed_set != set(expected_paths):
        missing = set(expected_paths) - changed_set
        extra = changed_set - set(expected_paths)
        parts = []
        if missing:
            parts.append(f"Missing changes: {', '.join(sorted(missing))}")
        if extra:
            parts.append(f"Unexpected changes: {', '.join(sorted(extra))}")
        _die("; ".join(parts))

    # Stage exactly the six manifest files.
    for p in expected_paths:
        _run(["git", "add", p])

    _write_github_output(args.github_output, {"has_changes": "true"})


# ---------------------------------------------------------------------------
# Subcommand: commit-push
# ---------------------------------------------------------------------------


def cmd_commit_push(args: argparse.Namespace):
    if not VERSION_RE.match(args.version):
        _die(f"--version: invalid version {args.version!r}")
    if not SHA_RE.match(args.expected_sha):
        _die(f"--expected-sha: invalid SHA {args.expected_sha!r}")
    if not args.head_ref:
        _die("--head-ref is required")
    if not REPO_RE.match(args.repository):
        _die(f"--repository: invalid format {args.repository!r}")

    formulae = _get_formulae(args.bump_script)
    expected_paths = _formula_paths(formulae)

    # Revalidate staged paths.
    r = _run(["git", "diff", "--cached", "--name-status"])
    staged: set[str] = set()
    for line in r.stdout.strip().split("\n"):
        line = line.strip()
        if not line:
            continue
        parts = line.split("\t", 1)
        if len(parts) != 2:
            _die(f"Cannot parse staged line: {line!r}")
        status, path = parts
        if status != "M":
            _die(f"Unexpected staged status {status!r} for {path}")
        if path not in expected_paths:
            _die(f"Staged path {path!r} is not a manifest path")
        staged.add(path)

    if staged != set(expected_paths):
        missing = set(expected_paths) - staged
        extra = staged - set(expected_paths)
        parts = []
        if missing:
            parts.append(f"Missing staged: {', '.join(sorted(missing))}")
        if extra:
            parts.append(f"Unexpected staged: {', '.join(sorted(extra))}")
        _die("; ".join(parts))

    # Ensure no unstaged or untracked files.
    r = _run(["git", "status", "--porcelain"])
    for line in r.stdout.strip().split("\n"):
        line = line.rstrip("\n")
        if not line:
            continue
        prefix = line[:2]
        if prefix == "??":
            _die(f"Untracked file before commit: {line[3:]}")
        # Reject any unstaged change — second-column activity (including MM).
        if prefix[1] != " ":
            _die(f"Unstaged change before commit: {line}")
        # At this point the entry is purely staged (first-column activity
        # with clean working tree).  Stage-only entries are validated above.

    # Git user config.
    _run(["git", "config", "user.name", "renovate[bot]"])
    _run(
        [
            "git",
            "config",
            "user.email",
            "29139614+renovate[bot]@users.noreply.github.com",
        ]
    )

    # Commit.
    msg = (
        f"build(tools): auto-bump remaining ggml-metal-dist formulae to {args.version}"
    )
    r = _run_nofail(["git", "commit", "-m", msg])
    if r.returncode != 0:
        _die(f"Commit failed:\n{r.stderr.strip()}")

    # Push with force-with-lease — token via GIT_ASKPASS, never in URL/args.
    token = os.environ.get("TOKEN")
    if not token:
        _die("TOKEN environment variable is not set")
    assert token is not None  # keep type checker happy

    # Write a temp GIT_ASKPASS credential helper.
    _askpass_dir = tempfile.mkdtemp(prefix="rb-askpass-")
    _askpass_path = os.path.join(_askpass_dir, "askpass.sh")
    try:
        with open(_askpass_path, "w") as f:
            f.write("#!/bin/sh\n")
            f.write('case "$1" in\n')
            f.write('  *Username*|*username*) echo "x-access-token" ;;\n')
            f.write('  *Password*|*password*) echo "$TOKEN" ;;\n')
            f.write('  *) echo "x-access-token" ;;\n')
            f.write("esac\n")
        os.chmod(_askpass_path, 0o755)

        push_env = os.environ.copy()
        push_env["TOKEN"] = token
        push_env["GIT_ASKPASS"] = _askpass_path

        push_args = [
            "git",
            "push",
            "origin",
            f"HEAD:{args.head_ref}",
            f"--force-with-lease={args.head_ref}:{args.expected_sha}",
        ]
        r = _run_nofail(push_args, env=push_env)
        if r.returncode != 0:
            _die(f"Push failed:\n{r.stderr.strip()}")
    finally:
        shutil.rmtree(_askpass_dir, ignore_errors=True)


# ---------------------------------------------------------------------------
# Argument parser
# ---------------------------------------------------------------------------


def _parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Renovate bump workflow driver.")
    sp = p.add_subparsers(dest="command", required=True)

    # validate-pr
    vp = sp.add_parser(
        "validate-pr", help="Validate PR diff, formula structure, canary"
    )
    vp.add_argument("--base-sha", required=True)
    vp.add_argument("--head-sha", required=True)
    vp.add_argument("--bump-script", required=True)
    vp.add_argument("--github-output", default=None)

    # apply-bump
    ab = sp.add_parser("apply-bump", help="Restore base and run trusted bump script")
    ab.add_argument("--base-sha", required=True)
    ab.add_argument("--version", required=True)
    ab.add_argument("--bump-script", required=True)
    ab.add_argument("--formula-dir", required=True)

    # stage
    st = sp.add_parser("stage", help="Verify and stage bumped formulae")
    st.add_argument("--bump-script", required=True)
    st.add_argument("--github-output", default=None)

    # commit-push
    cp = sp.add_parser("commit-push", help="Commit and push with force-with-lease")
    cp.add_argument("--version", required=True)
    cp.add_argument("--head-ref", required=True)
    cp.add_argument("--expected-sha", required=True)
    cp.add_argument("--repository", required=True)
    cp.add_argument("--bump-script", required=True)

    return p


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def main():
    p = _parser()
    args = p.parse_args()

    if args.command == "validate-pr":
        cmd_validate_pr(args)
    elif args.command == "apply-bump":
        cmd_apply_bump(args)
    elif args.command == "stage":
        cmd_stage(args)
    elif args.command == "commit-push":
        cmd_commit_push(args)
    else:
        p.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
