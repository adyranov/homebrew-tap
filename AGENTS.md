# Agent Guide

## Purpose and Scope

This repository is `adyranov/tap`, a personal, general-purpose Homebrew tap
for macOS software. Its current ggml-metal-dist-backed subset ships prebuilt
Metal-accelerated ML inference artifacts, but future formulae may cover other
software.

In scope: formula maintenance, shared install behavior, release automation,
Renovate, CI, tests, and documentation.

Out of scope: building or publishing artifacts, changing upstream projects,
bundling model weights, or copying assumptions from the upstream build
pipeline. Public contribution workflows are not a project goal.

## Repository Map

- `Formula/*.rb` — tap formulae; six current formulae are ggml-metal-dist-backed.
- `lib/metal_dist_install.rb` — shared installation and Mach-O fixups.
- `scripts/bump_ggml_metal_dist_formulae.rb` — trusted release updater.
- `test/` — offline updater tests.
- `.mise.toml` — local validation commands.
- `.github/workflows/` — lint, dual-architecture Homebrew CI, Renovate bump.
- `.github/renovate.json5` — dependency and release detection.
- `README.md` — user documentation.

## Core Invariants

### Current ggml-metal-dist-backed formulae

- `llama-cpp`
- `whisper-cpp`
- `stable-diffusion-cpp`
- `acestep-cpp`
- `crispasr`
- `omnivoice-cpp`

For these six formulae, release assets use:

```text
https://github.com/adyranov/ggml-metal-dist/releases/download/<tag>/<formula>-<tag>-<arch>-apple-darwin.tar.gz
```

Keep both architectures and all six formulae on the same release tag. Never
invent or copy unverified checksums. Prefer the tracked bump script over a
partial hand-edited release update:

```sh
ruby scripts/bump_ggml_metal_dist_formulae.rb vMAJOR.MINOR.PATCH
```

The updater validates release metadata and computes archive SHA-256 values.
Inspect its six-formula diff before accepting the result.

If the ggml-metal-dist-backed formula inventory changes, update the updater
manifest, workflow allowlists and assertions, tests, Renovate assumptions, and
README together.

Keep formulae hand-authored and DRY. Reuse `MetalDistInstall`; place only
formula-specific binary renames in `BIN_RENAMES`. Preserve formula tests,
conflict declarations, dependencies, caveats, and `livecheck`.

## Working Rules

1. Start with `git status --short` and inspect relevant diffs. Preserve
   pre-existing work.
2. Make the smallest focused change. Do not reformat unrelated files.
3. Prefer direct Homebrew commands; use custom scripts only where already
   established.
4. Use `rg` for repository searches.
5. Do not commit release archives, checksum sidecars, generated artifacts,
   caches, editor state, or secrets.
6. Update documentation when inventory, requirements, commands, caveats, or
   security behavior changes.

## Validation

Run narrow checks first:

```sh
mise run lint          # Ruby syntax, YAML loading, conflict markers, brew style
mise run test-offline  # bump-script tests
```

Run repository hooks when relevant; some hooks may rewrite files, so inspect
the diff afterward:

```sh
mise run pre-commit
```

For formula changes, run online and runtime checks as appropriate:

```sh
mise run audit
brew livecheck --formula adyranov/tap/<formula>
FORMULA=<formula> mise run install
FORMULA=<formula> mise run test
brew linkage --test --strict adyranov/tap/<formula>
```

Changes to shared install logic should exercise every formula. Changes to
Renovate configuration should also run the validator command used by
`.github/workflows/lint.yml`.

Full validation requires CI on both `arm64` and `x86_64`; do not claim
cross-architecture success from one local machine.

## Safety

- Never run `git reset --hard`, `git clean`, restore unrelated paths, or discard
  existing work without explicit approval.
- Treat the repository checkout as source. Do not edit an installed Homebrew
  tap clone under the Homebrew prefix.
- Local tap registration, trust, install, and uninstall commands mutate host
  state. Obtain approval before running them. If approved:

  ```sh
  brew tap --force adyranov/tap "$PWD"
  brew trust adyranov/tap
  ```

- Pin third-party GitHub Actions by full commit SHA and keep workflow
  permissions minimal.
- Preserve the `pull_request_target` trust boundary in
  `renovate-bump.yml`: never execute PR-provided code with secrets or write
  credentials; use trusted base-revision code, validate changed paths, and mint
  write credentials only for the final push.
- Verify release URLs and metadata against
  `adyranov/ggml-metal-dist` before changing formula URLs or checksums.
- `MachO.codesign!` is ad-hoc signing after install-time modification; it is
  not artifact identity, notarization, or provenance verification.
