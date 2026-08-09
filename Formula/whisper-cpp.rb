require_relative "../lib/metal_dist_install"

class WhisperCpp < Formula
  include MetalDistInstall

  desc "OpenAI Whisper in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.1/whisper-cpp-v26.8.1-arm64-apple-darwin.tar.gz"
    sha256 "034eab06c8662007c661436ff44fc2637d98260dc712fe430b55921dd428cba1"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.1/whisper-cpp-v26.8.1-x86_64-apple-darwin.tar.gz"
    sha256 "8d7ed888e991e96415a70ab6f7639eecb1646e4324b8a143fb31b68e5db1e053"
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
