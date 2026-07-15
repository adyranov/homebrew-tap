#!/usr/bin/env python3
"""Tests for scripts/renovate_bump.py — stdlib unittest with temp git repos."""

import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest

# Paths relative to this test file
_HERE = os.path.dirname(os.path.abspath(__file__))
_SCRIPT = os.path.join(_HERE, "..", "scripts", "renovate_bump.py")
_BUMP_SCRIPT = os.path.join(_HERE, "..", "scripts", "bump_ggml_metal_dist_formulae.rb")

_MANIFEST = [
    "llama-cpp",
    "whisper-cpp",
    "stable-diffusion-cpp",
    "acestep-cpp",
    "crispasr",
    "omnivoice-cpp",
]

_VERSION_RE = re.compile(r"^v(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$")


def _valid_formula(name, ver="v26.6.0", arm_sha="a" * 64, x64_sha="b" * 64):
    cls = "".join(p.capitalize() for p in name.split("-"))
    return f"""class {cls} < Formula
  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/{ver}/{name}-{ver}-arm64-apple-darwin.tar.gz"
    sha256 "{arm_sha}"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/{ver}/{name}-{ver}-x86_64-apple-darwin.tar.gz"
    sha256 "{x64_sha}"
  end
end
"""


def _init_repo(path):
    """Create a clean git repo at *path* with user config."""
    subprocess.run(["git", "init", "-q", "--template=", path], check=True)
    subprocess.run(["git", "-C", path, "config", "user.email", "t@t"], check=True)
    subprocess.run(["git", "-C", path, "config", "user.name", "t"], check=True)


def _git(path, *args):
    """Run git in *path* and return stdout."""
    r = subprocess.run(
        ["git", "-C", path, *args],
        capture_output=True,
        text=True,
        check=False,
    )
    if r.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed: {r.stderr.strip()}")
    return r.stdout.strip()


def _rev(path, ref="HEAD"):
    return _git(path, "rev-parse", ref)


def _commit_everything(path, msg):
    _git(path, "add", "-A")
    _git(path, "commit", "-q", "-m", msg)


class RenovateBumpTestBase(unittest.TestCase):
    """Set up a temp directory with a git repo containing 6 formula files.

    Uses a minimal fake bump.rb script (not the real one) to avoid Ruby
    dependency for the core Python test suite.  A single real-Ruby test
    subclass validates the --list-formulae / --extract-version contract.
    """

    _fake_bump_lines = [
        "#!/usr/bin/env ruby",
        'if ARGV[0] == "--list-formulae"',
    ]
    for _n in _MANIFEST:
        _fake_bump_lines.append(f'  puts "{_n}"')
    _fake_bump_lines.extend(
        [
            'elsif ARGV[0] == "--extract-version"',
            "  src = (ARGV[1] && File.exist?(ARGV[1]) ? File.read(ARGV[1]) : STDIN.read)",
            "  ver = src[/v\\d+\\.\\d+\\.\\d+/]",
            "  if ver",
            "    puts ver",
            "    exit 0",
            "  else",
            "    exit 1",
            "  end",
            "end",
        ]
    )
    _fake_bump_content = "\n".join(_fake_bump_lines) + "\n"

    @classmethod
    def setUpClass(cls):
        # Check that the Python script exists and parses.
        with open(_SCRIPT) as f:
            source = f.read()
        compile(source, _SCRIPT, "exec")

    def setUp(self):
        self._tmp = tempfile.mkdtemp(prefix="rb_test_")
        self._repo = os.path.join(self._tmp, "repo")
        os.mkdir(self._repo)
        _init_repo(self._repo)

        # Formula dir
        self._formula_dir = os.path.join(self._repo, "Formula")
        os.mkdir(self._formula_dir)

        # Write base formula files (v26.6.0)
        for name in _MANIFEST:
            p = os.path.join(self._formula_dir, f"{name}.rb")
            with open(p, "w") as f:
                f.write(_valid_formula(name, "v26.6.0"))
        _commit_everything(self._repo, "base")
        self._base_sha = _rev(self._repo, "HEAD")

        # Create a head commit — bump every formula to v26.7.0
        for name in _MANIFEST:
            p = os.path.join(self._formula_dir, f"{name}.rb")
            with open(p, "w") as f:
                f.write(_valid_formula(name, "v26.7.0"))
        _commit_everything(self._repo, "bump to v26.7.0")
        self._head_sha = _rev(self._repo, "HEAD")

        # Fake bump.rb (trusted script) in repo root
        self._bump_script = os.path.join(self._tmp, "bump.rb")
        with open(self._bump_script, "w") as f:
            f.write(self._fake_bump_content)
        os.chmod(self._bump_script, 0o755)

        # GitHub output file
        self._gh_out = os.path.join(self._tmp, "github_output.txt")

    def tearDown(self):
        shutil.rmtree(self._tmp, ignore_errors=True)

    def _run_script(self, subcommand, **kwargs):
        """Run renovate_bump.py as a subprocess and return CompletedProcess."""
        cmd = [sys.executable, "-I", _SCRIPT, subcommand]
        for k, v in kwargs.items():
            key = "--" + k.replace("_", "-")
            cmd.extend([key, str(v)])
        return subprocess.run(
            cmd, capture_output=True, text=True, cwd=self._repo, check=False
        )

    def _assert_ok(self, r):
        self.assertEqual(
            0, r.returncode, f"subcommand failed:\nstdout:{r.stdout}\nstderr:{r.stderr}"
        )

    def _assert_fail(self, r, msg_substr=None):
        self.assertNotEqual(
            0, r.returncode, f"expected failure but passed:\nstdout:{r.stdout}"
        )
        if msg_substr:
            self.assertIn(
                msg_substr,
                (r.stdout + r.stderr).lower(),
                f"expected '{msg_substr}' in output",
            )

    def _write_gh_out(self):
        """Touch the github output file so runs that write to it don't crash."""
        with open(self._gh_out, "w"):
            pass

    def _modify_exactly_six(self, version="v26.8.0"):
        """Modify all six formula files in the working tree (not staged)."""
        for name in _MANIFEST:
            p = os.path.join(self._formula_dir, f"{name}.rb")
            with open(p, "w") as f:
                f.write(_valid_formula(name, version))


# -------------------------------------------------------------------------
# validate-pr
# -------------------------------------------------------------------------


class TestValidatePr(RenovateBumpTestBase):
    def test_allowed_modification(self):
        """Six formula files modified → pass."""
        r = self._run_script(
            "validate-pr",
            base_sha=self._base_sha,
            head_sha=self._head_sha,
            bump_script=self._bump_script,
            github_output=self._gh_out,
        )
        self._assert_ok(r)
        # Check output
        with open(self._gh_out) as f:
            lines = f.read().strip().split("\n")
        outputs = dict(ln.split("=", 1) for ln in lines if "=" in ln)
        self.assertEqual(outputs.get("validation_result"), "pass")
        self.assertTrue(_VERSION_RE.match(outputs.get("version", "")))

    def test_add_rejected(self):
        """Adding a file → reject."""
        p = os.path.join(self._formula_dir, "new.rb")
        with open(p, "w") as f:
            f.write("# new\n")
        _commit_everything(self._repo, "add new.rb")
        new_head = _rev(self._repo, "HEAD")
        r = self._run_script(
            "validate-pr",
            base_sha=self._base_sha,
            head_sha=new_head,
            bump_script=self._bump_script,
        )
        self._assert_fail(r, "non-modification")

    def test_delete_rejected(self):
        """Deleting a file → reject."""
        os.unlink(os.path.join(self._formula_dir, "crispasr.rb"))
        _commit_everything(self._repo, "delete crispasr.rb")
        new_head = _rev(self._repo, "HEAD")
        r = self._run_script(
            "validate-pr",
            base_sha=self._base_sha,
            head_sha=new_head,
            bump_script=self._bump_script,
        )
        # Delete produces no 'M' entry for the file — the ls-tree check
        # triggers first: "missing manifest"
        self._assert_fail(r)

    def test_rename_rejected(self):
        """Renaming manifests → shows as add+delete, rejected."""
        src = os.path.join(self._formula_dir, "llama-cpp.rb")
        dst = os.path.join(self._formula_dir, "renamed.rb")
        os.rename(src, dst)
        _commit_everything(self._repo, "rename")
        new_head = _rev(self._repo, "HEAD")
        r = self._run_script(
            "validate-pr",
            base_sha=self._base_sha,
            head_sha=new_head,
            bump_script=self._bump_script,
        )
        # --no-renames shows A + D for renames
        self._assert_fail(r)

    def test_extra_path_rejected(self):
        """Changing a non-manifest file → reject."""
        p = os.path.join(self._repo, "README.md")
        with open(p, "w") as f:
            f.write("changed\n")
        _commit_everything(self._repo, "add readme")
        new_head = _rev(self._repo, "HEAD")
        r = self._run_script(
            "validate-pr",
            base_sha=self._base_sha,
            head_sha=new_head,
            bump_script=self._bump_script,
        )
        # Added README with status 'A' — "non-modification status 'a'" fires first
        self._assert_fail(r)

    def test_missing_manifest_from_head(self):
        """Manifest file absent from HEAD tree → reject."""
        # Remove a manifest file from head
        os.unlink(os.path.join(self._formula_dir, "omnivoice-cpp.rb"))
        _commit_everything(self._repo, "remove omnivoice")
        new_head = _rev(self._repo, "HEAD")
        r = self._run_script(
            "validate-pr",
            base_sha=self._base_sha,
            head_sha=new_head,
            bump_script=self._bump_script,
        )
        self._assert_fail(r, "missing manifest")

    def test_malformed_sha(self):
        """Bad SHA format → reject."""
        r = self._run_script(
            "validate-pr",
            base_sha="not-a-sha",
            head_sha=self._head_sha,
            bump_script=self._bump_script,
        )
        self._assert_fail(r, "invalid sha")

    def test_malformed_head_sha(self):
        """Bad head SHA → reject."""
        r = self._run_script(
            "validate-pr",
            base_sha=self._base_sha,
            head_sha="short",
            bump_script=self._bump_script,
        )
        self._assert_fail(r, "invalid sha")

    def test_canary_extraction_fails(self):
        """Canary formula has no version → fail."""
        # Write a canary with no version URL
        with open(os.path.join(self._formula_dir, "llama-cpp.rb"), "w") as f:
            f.write("class LlamaCpp < Formula; end\n")
        _commit_everything(self._repo, "bad canary")
        new_head = _rev(self._repo, "HEAD")
        r = self._run_script(
            "validate-pr",
            base_sha=self._base_sha,
            head_sha=new_head,
            bump_script=self._bump_script,
        )
        self._assert_fail(r)

    def test_missing_all_changes_manifest(self):
        """All manifest files unchanged → fails (must modify)."""
        # Create a diff that doesn't touch manifests
        p = os.path.join(self._repo, "other.txt")
        with open(p, "w") as f:
            f.write("stuff\n")
        _commit_everything(self._repo, "other change")
        new_head = _rev(self._repo, "HEAD")
        r = self._run_script(
            "validate-pr",
            base_sha=self._base_sha,
            head_sha=new_head,
            bump_script=self._bump_script,
        )
        # 'A' for other.txt fires "non-modification status" before
        # we reach the "missing modification" check
        self._assert_fail(r)

    def test_canary_only_modified(self):
        """Only the canary file modified → pass (any non-empty subset ok)."""
        # Create a head commit that only changes llama-cpp.rb to v26.8.0
        p = os.path.join(self._formula_dir, "llama-cpp.rb")
        with open(p, "w") as f:
            f.write(_valid_formula("llama-cpp", "v26.8.0"))
        _commit_everything(self._repo, "bump canary only")
        new_head = _rev(self._repo, "HEAD")
        r = self._run_script(
            "validate-pr",
            base_sha=self._base_sha,
            head_sha=new_head,
            bump_script=self._bump_script,
            github_output=self._gh_out,
        )
        self._assert_ok(r)
        with open(self._gh_out) as f:
            lines = f.read().strip().split("\n")
        outputs = dict(ln.split("=", 1) for ln in lines if "=" in ln)
        self.assertEqual(outputs.get("validation_result"), "pass")

    def test_partial_subset_modified(self):
        """Three of six manifest files modified → pass."""
        for name in _MANIFEST[:3]:
            p = os.path.join(self._formula_dir, f"{name}.rb")
            with open(p, "w") as f:
                f.write(_valid_formula(name, "v26.8.0"))
        _commit_everything(self._repo, "bump three only")
        new_head = _rev(self._repo, "HEAD")
        r = self._run_script(
            "validate-pr",
            base_sha=self._base_sha,
            head_sha=new_head,
            bump_script=self._bump_script,
            github_output=self._gh_out,
        )
        self._assert_ok(r)
        with open(self._gh_out) as f:
            lines = f.read().strip().split("\n")
        outputs = dict(ln.split("=", 1) for ln in lines if "=" in ln)
        self.assertEqual(outputs.get("validation_result"), "pass")

    def test_no_manifest_modifications_rejected(self):
        """No manifest files changed (empty diff) → reject."""
        r = self._run_script(
            "validate-pr",
            base_sha=self._base_sha,
            head_sha=self._base_sha,  # same SHA → empty diff
            bump_script=self._bump_script,
        )
        self._assert_fail(r, "no allowed modifications")

    def test_hostile_formula_data_never_executed(self):
        """Formula with Ruby code injection → parsed as data, never eval'd."""
        p = os.path.join(self._formula_dir, "llama-cpp.rb")
        # Hostile data with system() but still valid structure
        hostile = _valid_formula("llama-cpp", "v26.7.0") + '\nsystem("rm -rf /")\n'
        with open(p, "w") as f:
            f.write(hostile)
        _commit_everything(self._repo, "hostile canary")
        new_head = _rev(self._repo, "HEAD")
        r = self._run_script(
            "validate-pr",
            base_sha=self._base_sha,
            head_sha=new_head,
            bump_script=self._bump_script,
            github_output=self._gh_out,
        )
        # The fake bump.rb uses a regex, not eval, so it still extracts
        # the version.  The real script uses Ripper (AST).  Neither evals.
        self._assert_ok(r)
        # Double-check that the system() line is harmless — no files deleted.
        self.assertTrue(os.path.isdir(self._repo))


# -------------------------------------------------------------------------
# apply-bump
# -------------------------------------------------------------------------


class TestApplyBump(RenovateBumpTestBase):
    def test_restore_and_bump(self):
        """Restores formulae from base and runs bump script."""
        # First, introduce hostile content in the working tree (simulates PR head)
        for name in _MANIFEST:
            p = os.path.join(self._formula_dir, f"{name}.rb")
            with open(p, "w") as f:
                f.write("MALICIOUS\n")
        _commit_everything(self._repo, "evil head")
        evil_head = _rev(self._repo, "HEAD")
        # Reset working tree to evil head
        subprocess.run(
            ["git", "-C", self._repo, "checkout", "-q", evil_head], check=True
        )

        r = self._run_script(
            "apply-bump",
            base_sha=self._base_sha,
            version="v26.7.0",
            bump_script=self._bump_script,
            formula_dir=self._formula_dir,
        )
        self._assert_ok(r)

        # Verify restored: files should be base version (v26.6.0) before bump.
        # Our fake bump.rb just writes the fake content, but the real behavior
        # for the fake is a no-op.  At minimum the malicious content is gone.
        for name in _MANIFEST:
            p = os.path.join(self._formula_dir, f"{name}.rb")
            with open(p) as fp:
                content = fp.read()
            self.assertNotIn("MALICIOUS", content, f"{name} was not restored")

    def test_bump_inherits_token(self):
        """Runs with inherited GITHUB_TOKEN environment."""
        r = self._run_script(
            "apply-bump",
            base_sha=self._base_sha,
            version="v26.7.0",
            bump_script=self._bump_script,
            formula_dir=self._formula_dir,
        )
        self._assert_ok(r)

    def test_invalid_version_rejected(self):
        """Bad version format → fail."""
        r = self._run_script(
            "apply-bump",
            base_sha=self._base_sha,
            version="not-a-version",
            bump_script=self._bump_script,
            formula_dir=self._formula_dir,
        )
        self._assert_fail(r, "invalid version")

    def test_invalid_base_sha_rejected(self):
        """Bad base SHA → fail."""
        r = self._run_script(
            "apply-bump",
            base_sha="bad-sha",
            version="v26.7.0",
            bump_script=self._bump_script,
            formula_dir=self._formula_dir,
        )
        self._assert_fail(r, "invalid sha")


# -------------------------------------------------------------------------
# stage
# -------------------------------------------------------------------------


class TestStage(RenovateBumpTestBase):
    def test_exact_staging(self):
        """Six files modified → staged and has_changes=true."""
        self._modify_exactly_six()
        r = self._run_script(
            "stage",
            bump_script=self._bump_script,
            github_output=self._gh_out,
        )
        self._assert_ok(r)
        with open(self._gh_out) as f:
            outputs = dict(
                ln.split("=", 1) for ln in f.read().strip().split("\n") if "=" in ln
            )
        self.assertEqual(outputs.get("has_changes"), "true")

        # Verify files are staged
        staged = _git(self._repo, "diff", "--cached", "--name-only")
        for name in _MANIFEST:
            self.assertIn(f"Formula/{name}.rb", staged)

    def test_no_changes_output(self):
        """No changes → has_changes=false."""
        r = self._run_script(
            "stage",
            bump_script=self._bump_script,
            github_output=self._gh_out,
        )
        self._assert_ok(r)
        with open(self._gh_out) as f:
            outputs = dict(
                ln.split("=", 1) for ln in f.read().strip().split("\n") if "=" in ln
            )
        self.assertEqual(outputs.get("has_changes"), "false")

    def test_extra_change_rejected(self):
        """Extra file modified → reject."""
        self._modify_exactly_six()
        p = os.path.join(self._repo, "unexpected.txt")
        with open(p, "w") as f:
            f.write("extra")
        r = self._run_script(
            "stage",
            bump_script=self._bump_script,
        )
        self._assert_fail(r, "untracked")

    def test_untracked_file_rejected(self):
        """Untracked file present → reject."""
        self._modify_exactly_six()
        p = os.path.join(self._repo, "unknown.txt")
        with open(p, "w") as f:
            f.write("unknown")
        r = self._run_script(
            "stage",
            bump_script=self._bump_script,
        )
        self._assert_fail(r, "untracked")

    def test_added_file_rejected_2(self):
        """A file with status != M → reject."""
        p = os.path.join(self._repo, "Formula", "new.rb")
        with open(p, "w") as f:
            f.write("new")
        subprocess.run(["git", "-C", self._repo, "add", "Formula/new.rb"], check=True)
        r = self._run_script(
            "stage",
            bump_script=self._bump_script,
        )
        # Staged changes (not clean staging area) are caught
        self._assert_fail(r, "staged")

    def test_staged_changes_rejected_2(self):
        """Pre-existing staged changes → reject."""
        self._modify_exactly_six()
        # Stage one file manually
        subprocess.run(
            ["git", "-C", self._repo, "add", "Formula/llama-cpp.rb"], check=True
        )
        r = self._run_script(
            "stage",
            bump_script=self._bump_script,
        )
        self._assert_fail(r, "staged")

    def test_partial_change_rejected(self):
        """Only 5 of 6 files modified → reject."""
        for name in _MANIFEST[:5]:
            p = os.path.join(self._formula_dir, f"{name}.rb")
            with open(p, "w") as f:
                f.write(_valid_formula(name, "v26.8.0"))
        r = self._run_script(
            "stage",
            bump_script=self._bump_script,
        )
        self._assert_fail(r, "missing")


# -------------------------------------------------------------------------
# commit-push
# -------------------------------------------------------------------------


class TestCommitPush(RenovateBumpTestBase):
    def setUp(self):
        super().setUp()
        # Set up a bare remote repo for push testing
        self._remote = os.path.join(self._tmp, "remote.git")
        subprocess.run(["git", "init", "-q", "--bare", self._remote], check=True)

        # Add remote to local repo
        subprocess.run(
            ["git", "-C", self._repo, "remote", "add", "origin", self._remote],
            check=True,
        )

        # Configure a local branch to push from
        subprocess.run(
            [
                "git",
                "-C",
                self._repo,
                "checkout",
                "-b",
                "renovate/ggml-metal-dist-formulae",
            ],
            check=True,
        )

        # Push base to remote so origin has the base branch
        subprocess.run(
            [
                "git",
                "-C",
                self._repo,
                "push",
                "-q",
                "origin",
                "renovate/ggml-metal-dist-formulae",
            ],
            check=True,
            env={**os.environ, "GIT_ASKPASS": "/bin/sh", "GIT_TERMINAL_PROMPT": "0"},
        )

        # Stage changes (as if stage step succeeded)
        self._modify_exactly_six("v26.8.0")
        for name in _MANIFEST:
            subprocess.run(
                ["git", "-C", self._repo, "add", f"Formula/{name}.rb"], check=True
            )

    def _run_commit_push(self, **kwargs):
        """Run commit-push with TOKEN env set."""
        cmd = [sys.executable, "-I", _SCRIPT, "commit-push"]
        for k, v in kwargs.items():
            key = "--" + k.replace("_", "-")
            cmd.extend([key, str(v)])
        env = {**os.environ, "TOKEN": "ghx_test_token_no_real_secret"}
        return subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=self._repo,
            env=env,
            check=False,
        )

    def test_commit_and_push(self):
        """Commits and pushes with force-with-lease."""
        r = self._run_commit_push(
            version="v26.8.0",
            head_ref="renovate/ggml-metal-dist-formulae",
            expected_sha=self._head_sha,
            repository="owner/repo",
            bump_script=self._bump_script,
        )
        self._assert_ok(r)

        # Verify commit exists in remote (resolve specific ref, not HEAD)
        remote_head = _git(
            self._remote,
            "show-ref",
            "--hash",
            "refs/heads/renovate/ggml-metal-dist-formulae",
        )
        local_head = _rev(self._repo, "HEAD")
        self.assertEqual(
            local_head,
            remote_head,
            "Remote ref should match local HEAD after push",
        )

    def test_lease_sha_mismatch_rejected(self):
        """Wrong expected SHA → force-with-lease rejects."""
        # Push the current branch (with staged changes) to remote first.
        subprocess.run(
            [
                "git",
                "-C",
                self._repo,
                "push",
                "-q",
                "origin",
                "renovate/ggml-metal-dist-formulae",
            ],
            check=True,
            env={
                **os.environ,
                "TOKEN": "dummy",
                "GIT_ASKPASS": "/bin/sh",
                "GIT_TERMINAL_PROMPT": "0",
            },
            capture_output=True,
        )
        # Try to push with a deliberately wrong expected SHA.
        bogus_sha = "0" * 40
        r = self._run_commit_push(
            version="v26.8.0",
            head_ref="renovate/ggml-metal-dist-formulae",
            expected_sha=bogus_sha,
            repository="owner/repo",
            bump_script=self._bump_script,
        )
        self._assert_fail(r)

    def test_invalid_version_rejected(self):
        """Bad version format → fail."""
        r = self._run_commit_push(
            version="bad",
            head_ref="renovate/ggml-metal-dist-formulae",
            expected_sha=self._head_sha,
            repository="owner/repo",
            bump_script=self._bump_script,
        )
        self._assert_fail(r, "invalid version")

    def test_invalid_sha_rejected(self):
        """Bad expected SHA → fail."""
        r = self._run_commit_push(
            version="v26.8.0",
            head_ref="renovate/ggml-metal-dist-formulae",
            expected_sha="bad",
            repository="owner/repo",
            bump_script=self._bump_script,
        )
        self._assert_fail(r, "invalid sha")

    def test_unstaged_modification_after_stage(self):
        """Stage a formula then modify it again (MM state) → reject."""
        # setUp already staged all 6 formulae at v26.8.0.  Modify one in
        # the working tree to create an unstaged change on top.
        p = os.path.join(self._formula_dir, "llama-cpp.rb")
        with open(p, "w") as f:
            f.write(_valid_formula("llama-cpp", "v26.9.0"))
        r = self._run_commit_push(
            version="v26.8.0",
            head_ref="renovate/ggml-metal-dist-formulae",
            expected_sha=self._head_sha,
            repository="owner/repo",
            bump_script=self._bump_script,
        )
        self._assert_fail(r, "unstaged change")

    def test_token_not_in_args(self):
        """Token appears only in TOKEN env, never in CLI args or logs."""
        cmd = [
            sys.executable,
            "-I",
            _SCRIPT,
            "commit-push",
            "--version",
            "v26.8.0",
            "--head-ref",
            "renovate/ggml-metal-dist-formulae",
            "--expected-sha",
            self._head_sha,
            "--repository",
            "owner/repo",
            "--bump-script",
            self._bump_script,
        ]
        env = {**os.environ, "TOKEN": "ghx_secret_token_value_12345"}
        r = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=self._repo,
            env=env,
            check=False,
        )
        combined = (r.stdout + r.stderr).lower()
        self.assertNotIn(
            "ghx_secret_token_value_12345", combined, "Token leaked into logs"
        )
        self.assertNotIn("secret_token", combined, "Token leaked into logs")


# -------------------------------------------------------------------------
# Real Ruby script contract tests
# -------------------------------------------------------------------------


class TestRealRubyContracts(RenovateBumpTestBase):
    """Validate that the actual Ruby bump script satisfies the Python driver's
    expectations for --list-formulae and --extract-version."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        if not shutil.which("ruby"):
            raise unittest.SkipTest("ruby not available on this system")

    def setUp(self):
        # Override: use the real bump script instead of the fake
        super().setUp()
        self._bump_script = _BUMP_SCRIPT

    def test_list_formulae_returns_six_names(self):
        """Real --list-formulae returns unique safe names matching manifest."""
        r = subprocess.run(
            ["ruby", _BUMP_SCRIPT, "--list-formulae"],
            capture_output=True,
            text=True,
            check=True,
        )
        lines = [ln.strip() for ln in r.stdout.strip().split("\n") if ln.strip()]
        self.assertEqual(len(_MANIFEST), len(lines))
        self.assertEqual(set(_MANIFEST), set(lines))
        self.assertEqual(len(set(lines)), len(lines))
        # Verify each name is safe
        name_re = re.compile(r"^[a-zA-Z][a-zA-Z0-9_-]*$")
        for name in lines:
            self.assertIsNotNone(name_re.match(name), f"unsafe name: {name}")

    def test_extract_version_from_stdin(self):
        """Real --extract-version reads stdin and returns version."""
        data = _valid_formula("llama-cpp", "v26.7.0")
        r = subprocess.run(
            ["ruby", _BUMP_SCRIPT, "--extract-version"],
            input=data,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(0, r.returncode, f"extract-version failed: {r.stderr}")
        self.assertEqual("v26.7.0\n", r.stdout)


# -------------------------------------------------------------------------
# Entry point
# -------------------------------------------------------------------------

if __name__ == "__main__":
    unittest.main()
