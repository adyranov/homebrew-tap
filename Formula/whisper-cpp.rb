require_relative "../lib/metal_dist_install"

class WhisperCpp < Formula
  include MetalDistInstall

  desc "OpenAI Whisper in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.2/whisper-cpp-v26.7.2-arm64-apple-darwin.tar.gz"
    sha256 "67bea279105bfcc1439ba2fcd51bdf54add5b202c9aa9faf7258ec6deb42240d"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.2/whisper-cpp-v26.7.2-x86_64-apple-darwin.tar.gz"
    sha256 "c38e9a1c50aae28a28608434642b6f5f111c639de5e5f8e5c17f6e722ccc6fd0"
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
