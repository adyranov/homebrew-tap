# 🍺 Homebrew Tap

Personal Homebrew tap for macOS formulae — tools, utilities, and custom builds.

## 🚀 Usage

```sh
brew tap adyranov/tap
brew install adyranov/tap/<formula>
```

Example:

```sh
brew install adyranov/tap/llama-cpp
brew install adyranov/tap/whisper-cpp
brew install adyranov/tap/stable-diffusion-cpp
brew install adyranov/tap/acestep-cpp
brew install adyranov/tap/crispasr
brew install adyranov/tap/omnivoice-cpp
```

## 📦 Formulae

| Formula                | Description                                                                                | Notes                                              |
| ---------------------- | ------------------------------------------------------------------------------------------ | -------------------------------------------------- |
| `llama-cpp`            | LLM inference ([llama.cpp](https://github.com/ggml-org/llama.cpp)), Metal-accelerated      | Conflicts with `llama.cpp`                         |
| `whisper-cpp`          | Speech-to-text ([whisper.cpp](https://github.com/ggml-org/whisper.cpp)), Metal-accelerated | Bundles parakeet; conflicts with core `whisper-cpp`; interactive tools need `sdl2` |
| `stable-diffusion-cpp` | Image generation, Metal-accelerated                                                        | —                                                  |
| `acestep-cpp`          | Music generation ([acestep.cpp](https://github.com/ServeurpersoCom/acestep.cpp)), Metal-accelerated | Utility binaries use `ace-*` prefixes       |
| `crispasr`             | Multilingual ASR ([CrispASR](https://github.com/CrispStrobe/CrispASR)), Metal-accelerated  | —                                                  |
| `omnivoice-cpp`        | Text-to-speech ([omnivoice.cpp](https://github.com/ServeurpersoCom/omnivoice.cpp)), Metal-accelerated | Utility binaries use `omnivoice-*` prefixes |
