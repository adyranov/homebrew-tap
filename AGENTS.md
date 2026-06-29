# Agent Guidance

This repository is a small Homebrew tap for prebuilt macOS artifacts from
`adyranov/ggml-metal-dist`. Keep changes focused on formula maintenance,
Renovate configuration, and lightweight validation.

## Repository Shape

- Formulae live in `Formula/*.rb`.
- Shared install logic lives in `lib/metal_dist_install.rb`.
- Renovate tracks upstream GitHub release URLs and SHA256 values.
- CI should validate formula syntax/style/audit and install tests on macOS.

The formulae use release assets shaped like:

```text
https://github.com/adyranov/ggml-metal-dist/releases/download/<tag>/<tool>-<tag>-<arch>-apple-darwin.tar.gz
```

Do not copy build-pipeline assumptions from `ggml-metal-dist`; this tap does
not build upstream projects or publish releases.

## Working Rules

- Prefer direct Homebrew commands over custom scripts.
- Keep formulae hand-authored and DRY.
- Use `rg` for searches.
- Do not add generated build artifacts, release tarballs, checksum sidecars, or local Homebrew caches.
- Treat the installed Homebrew tap clone under `/usr/local/Homebrew/Library/Taps/...` as local state, not source.

Homebrew 6 may reject untrusted local taps. For local name-based validation, run:

```sh
brew tap --force adyranov/tap "$PWD"
brew trust adyranov/tap
```

If the installed tap clone has unresolved conflicts, repair that clone rather
than editing formulae in place:

```sh
git -C /usr/local/Homebrew/Library/Taps/adyranov/homebrew-tap merge --abort || true
git -C /usr/local/Homebrew/Library/Taps/adyranov/homebrew-tap reset --hard origin/main
```

## Validation

Run the narrow checks first:

```sh
mise run syntax
mise run yaml
mise run conflict-markers
brew style Formula/*.rb lib/*.rb
```

For full formula validation:

```sh
brew audit --strict --online --formula \
  llama-cpp whisper-cpp stable-diffusion-cpp \
  acestep-cpp crispasr omnivoice-cpp
brew install adyranov/tap/llama-cpp
brew test adyranov/tap/llama-cpp
```

Use `FORMULA=<name> mise run install` or `FORMULA=<name> mise run test` for a
single formula.

## CI And Renovate

- GitHub Actions must pin third-party actions by commit SHA.
- Renovate config lives in `.github/renovate.json5`.
- Use `helpers:pinGitHubActionDigests` so Renovate maintains action pins.
- Keep pre-commit hooks scoped to tap metadata, formula syntax, and cheap repository hygiene.
- ggml-metal-dist formula bumps use a custom Renovate regex manager (canary: `llama-cpp`) plus `scripts/bump_ggml_metal_dist_formulae.rb` in `postUpgradeTasks`, because the built-in homebrew manager only handles a single `url`/`sha256` and generic GitHub release asset names.

When changing formula release URLs or checksums, verify against the upstream
GitHub release metadata before editing.
