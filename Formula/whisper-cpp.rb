require_relative "../lib/metal_dist_install"

class WhisperCpp < Formula
  include MetalDistInstall

  desc "OpenAI Whisper in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.0/whisper-cpp-v26.8.0-arm64-apple-darwin.tar.gz"
    sha256 "4c6560996d37e0b0b620ce4ce6e0a57f322cd90377c8bdc3a201c5048a817cf5"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.0/whisper-cpp-v26.8.0-x86_64-apple-darwin.tar.gz"
    sha256 "7209b5a175d65e460198cf90d58031bbb39d3cb25f18994512122294c83fa502"
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
