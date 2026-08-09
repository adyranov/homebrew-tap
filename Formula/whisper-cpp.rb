require_relative "../lib/metal_dist_install"

class WhisperCpp < Formula
  include MetalDistInstall

  desc "OpenAI Whisper in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.2/whisper-cpp-v26.8.2-arm64-apple-darwin.tar.gz"
    sha256 "5ff816d965027cf2e592f729bbfbec81001d383e7dae636e92800f1e6176482f"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.2/whisper-cpp-v26.8.2-x86_64-apple-darwin.tar.gz"
    sha256 "997ebb73e4322acae45547282ef16db9006976fc9d81eab582d64c212749bbe7"
  end

  livecheck do
    url :homepage
    strategy :github_latest
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  depends_on macos: :sequoia
  depends_on "sdl2-compat"

  conflicts_with "whisper-cpp",
                 because: "both install whisper-* binaries (core uses system ggml; tap embeds Metal-patched ggml)"

  def caveats
    <<~EOS
      Bundles parakeet-cli and parakeet-quantize since v26.6.1. Conflicts with Homebrew core whisper-cpp.
      whisper-stream, whisper-command, and whisper-talk-llama require SDL2 (declared as depends_on).
      whisper-cli file transcription does not use SDL2 at runtime.
    EOS
  end

  test do
    assert_path_exists bin/"whisper-cli"
    assert_path_exists bin/"parakeet-cli"
    out = shell_output("#{bin}/whisper-cli --help 2>&1")
    assert_match(/usage:/i, out)
  end
end
