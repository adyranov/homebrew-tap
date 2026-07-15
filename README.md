# Homebrew Tap — adyranov/tap

Personal Homebrew tap for macOS software — currently ships prebuilt
Metal-accelerated ML inference tools backed by
[adyranov/ggml-metal-dist](https://github.com/adyranov/ggml-metal-dist).

## Quick start

```sh
brew tap adyranov/tap
brew install adyranov/tap/llama-cpp
```

## Requirements

| Aspect            | Details                                                                          |
| ----------------- | -------------------------------------------------------------------------------- |
| **macOS**         | macOS 15 Sequoia (arm64 and x86_64).                                             |
| **Architectures** | arm64 (Apple Silicon) and x86_64 (Intel) — per-formula dual-arch URLs.           |
| **Homebrew**      | Latest stable recommended. Older versions may work but are untested.             |

Artifacts are distributed as single-architecture tarballs per supported
architecture.

## Current formulae (ggml-metal-dist-backed)

| Formula | Upstream | Description |
| ------- | -------- | ----------- |
| `llama-cpp` | [llama.cpp](https://github.com/ggml-org/llama.cpp) | LLM inference, Metal-accelerated. Conflicts with Homebrew core `llama.cpp` (both ship `llama-*` binaries with embedded Metal-patched ggml). |
| `whisper-cpp` | [whisper.cpp](https://github.com/ggml-org/whisper.cpp) | Speech-to-text, Metal-accelerated. Bundles `parakeet-cli`/`parakeet-quantize`. Conflicts with Homebrew core `whisper-cpp`. Interactive tools (`whisper-stream`, `whisper-command`, `whisper-talk-llama`) need `sdl2-compat`. |
| `stable-diffusion-cpp` | [stable-diffusion.cpp](https://github.com/ggml-org/stable-diffusion.cpp) | Image generation, Metal-accelerated. |
| `acestep-cpp` | [acestep.cpp](https://github.com/ServeurpersoCom/acestep.cpp) | ACE-Step 1.5 music generation, Metal-accelerated. Utility binaries installed with `ace-` prefixes (e.g. `ace-quantize`). |
| `crispasr` | [CrispASR](https://github.com/CrispStrobe/CrispASR) | Multilingual ASR (fork of whisper.cpp), Metal-accelerated. |
| `omnivoice-cpp` | [omnivoice.cpp](https://github.com/ServeurpersoCom/omnivoice.cpp) | Text-to-speech, Metal-accelerated. Utility binaries installed with `omnivoice-` prefixes (e.g. `omnivoice-quantize`). |

All six formulae share the `MetalDistInstall` module which patches eligible
Mach-O files (dylib-id normalisation, rpath pointing to the formula keg's
`lib` directory, ad-hoc codesign) at install time. Non-Mach-O files and
symlinks are left unchanged.
Model weights are **not** bundled — see each upstream project's documentation
for GGUF model downloads.

## Install, upgrade, uninstall

### Tap (one-time)

```sh
brew tap adyranov/tap
```

Verify the tap is active:

```sh
brew tap | grep adyranov/tap
```

### Install a formula

```sh
brew install adyranov/tap/llama-cpp
# or shorter after tap:
brew install llama-cpp
```

### Upgrade

```sh
brew upgrade adyranov/tap/llama-cpp
# or upgrade all tapped formulae:
brew upgrade
```

### Uninstall

```sh
brew uninstall adyranov/tap/llama-cpp
brew untap adyranov/tap   # optional — removes the tap entirely
```

## Troubleshooting

### Conflicts

**`llama.cpp` conflict:** Homebrew core `llama.cpp` and `adyranov/tap/llama-cpp`
both install `llama-*` binaries. Uninstall one before installing the other.

**`whisper-cpp` conflict:** Homebrew core `whisper-cpp` and `adyranov/tap/whisper-cpp`
share the same formula name from different taps. Only one may be installed at a
time.

### Linkage errors

After install, eligible Mach-O files are patched with an `@rpath` pointing
to the formula keg's `lib` directory and ad-hoc codesigned. If you see
`Library not loaded` errors:

```sh
brew linkage --test --strict adyranov/tap/llama-cpp
```

This checks that every library dependency resolves within Homebrew's prefix
and the macOS SDK. A passing `brew linkage` is enforced in CI.

### Codesign issues

The `MetalDistInstall` module runs `MachO.codesign!` after patching dylibs.
If macOS still flags a binary as damaged or untrusted, reinstall the formula:

```sh
brew reinstall adyranov/tap/llama-cpp
```

Persistent codesign failures may indicate a corrupted install — reinstall the formula.

### Formula not found

Re-register the tap:

```sh
brew untap adyranov/tap 2>/dev/null; brew tap adyranov/tap
```

## Diagnostics

Run these commands to gather environment and formula state:

```sh
brew config                     # Homebrew version, macOS, compiler, arch
brew doctor                     # health check
brew gist-logs adyranov/tap/llama-cpp   # upload full logs to a Gist
```

### Per-formula state

```sh
brew info adyranov/tap/llama-cpp
brew list --formula adyranov/tap/llama-cpp
brew linkage adyranov/tap/llama-cpp
```

## Local validation

Run local validation checks. Requires `mise` (see `mise.toml`) or direct
Homebrew commands.

```sh
# Syntax check on all Ruby files
mise run syntax

# YAML structure check on workflow files
mise run yaml

# Conflict-marker detection
mise run conflict-markers

# Homebrew formula style
mise run style

# Full audit (online — fetches upstream metadata)
mise run audit

# Single formula (example)
mise run install   # installs llama-cpp by default
FORMULA=whisper-cpp mise run test

# Offline test for the bump script
mise run test-offline
```

These are local validation checks — CI additionally runs livecheck,
install/test, linkage, architecture verification, conflict, and rename
checks on both arm64 and x86_64 runners.

## Release automation

This tap does not build upstream projects or publish releases. It tracks
prebuilt artifacts published by
[adyranov/ggml-metal-dist](https://github.com/adyranov/ggml-metal-dist).

Releases in `ggml-metal-dist` are picked up by Renovate configured with a
custom regex manager (canary: `Formula/llama-cpp.rb`). When Renovate opens a
PR bumping the canary formula, a dedicated workflow
(`renovate-bump.yml`) runs a trusted bump script to update the remaining five
formulae.

To trigger a manual update:

```sh
ruby scripts/bump_ggml_metal_dist_formulae.rb vX.Y.Z
```

See `scripts/bump_ggml_metal_dist_formulae.rb` and
`.github/renovate.json5` for details.

This repository is personal and not open for public contributions. External
PRs will not be accepted.

## License

MIT — see `LICENSE`.
