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
brew install adyranov/tap/parakeet-cpp
```

## 📦 Formulae

| Formula                | Description                                                                                | Notes                         |
| ---------------------- | ------------------------------------------------------------------------------------------ | ----------------------------- |
| `llama-cpp`            | LLM inference ([llama.cpp](https://github.com/ggml-org/llama.cpp)), Metal-accelerated      | Conflicts with `llama.cpp`    |
| `whisper-cpp`          | Speech-to-text ([whisper.cpp](https://github.com/ggml-org/whisper.cpp)), Metal-accelerated | Interactive tools need `sdl2` |
| `stable-diffusion-cpp` | Image generation, Metal-accelerated                                                        | —                             |
| `parakeet-cpp`         | Speech-to-text ([parakeet.cpp](https://github.com/mudler/parakeet.cpp)), Metal-accelerated | —                             |
