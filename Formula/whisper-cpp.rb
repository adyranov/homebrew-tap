require_relative "../lib/metal_dist_install"

class WhisperCpp < Formula
  include MetalDistInstall

  desc "OpenAI Whisper in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.1/whisper-cpp-v26.6.1-arm64-apple-darwin.tar.gz"
    sha256 "68924daa640d1c1fe235213d3c39927d483f307d0630ff4935e583f4eb181096"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.1/whisper-cpp-v26.6.1-x86_64-apple-darwin.tar.gz"
    sha256 "aad52bd4492a0384ca205a3e0baba63eb78f060613cc35be4f3f98fc6dc49698"
  end

  depends_on macos: :sonoma
  depends_on "sdl2"

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
    assert out.length > 20
  end
end
