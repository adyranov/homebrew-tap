require_relative "../lib/metal_dist_install"

class WhisperCpp < Formula
  include MetalDistInstall

  desc "OpenAI Whisper in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.0/whisper-cpp-v26.7.0-arm64-apple-darwin.tar.gz"
    sha256 "53558fbdd7fc536cdf48c53ceb31be9dc125fadc464f9f40d2175b6acfeba9ea"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.0/whisper-cpp-v26.7.0-x86_64-apple-darwin.tar.gz"
    sha256 "1397d9dacad6f3bb91c2a3f84b4f7abe581db81c175aec77f347cca6335d678d"
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
