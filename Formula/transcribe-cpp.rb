require_relative "../lib/metal_dist_install"

class TranscribeCpp < Formula
  include MetalDistInstall

  desc "Audio transcription in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.2/transcribe-cpp-v26.8.2-arm64-apple-darwin.tar.gz"
    sha256 "234a9b92f884384313808fe85623c5b3bc2191f9274a544233da57f63545b71e"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.2/transcribe-cpp-v26.8.2-x86_64-apple-darwin.tar.gz"
    sha256 "02052b43dfec4dcaf05b525c3b990b9f2f7b1aba88e88a416a1b9ea53dc0d8f0"
  end

  livecheck do
    url :homepage
    strategy :github_latest
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  depends_on macos: :sequoia

  def caveats
    <<~EOS
      Model weights are not included. See upstream docs for GGUF models.
      Usage: transcribe-cli -m model.gguf audio.wav
    EOS
  end

  test do
    assert_path_exists bin/"transcribe-cli"
    out = shell_output("#{bin}/transcribe-cli --help 2>&1")
    assert_match(/usage:/i, out)
  end
end
