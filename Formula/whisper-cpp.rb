require_relative "../lib/metal_dist_install"

class WhisperCpp < Formula
  include MetalDistInstall

  desc "OpenAI Whisper in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.0/whisper-cpp-v26.6.0-arm64-apple-darwin.tar.gz"
    sha256 "4f7410683d582572ca330ce646b54ef2036819be2ea0e6f76922896859fd338e"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.0/whisper-cpp-v26.6.0-x86_64-apple-darwin.tar.gz"
    sha256 "7dc56bc647cfc73bb1e6bef885a06aeca8d562408a1f1f6f4e38d9eabc388d41"
  end

  depends_on macos: :sonoma
  depends_on "sdl2"

  def caveats
    <<~EOS
      whisper-stream, whisper-command, and whisper-talk-llama require SDL2 (declared as depends_on).
      whisper-cli file transcription does not use SDL2 at runtime.
    EOS
  end

  test do
    assert_path_exists bin/"whisper-cli"
    out = shell_output("#{bin}/whisper-cli --help 2>&1")
    assert out.length > 20
  end
end
