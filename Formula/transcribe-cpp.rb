require_relative "../lib/metal_dist_install"

class TranscribeCpp < Formula
  include MetalDistInstall

  desc "Audio transcription in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.1/transcribe-cpp-v26.8.1-arm64-apple-darwin.tar.gz"
    sha256 "66c8d39585bd4e43845d3cacc6eac07e286637cb0bea1ade582ec451cc569be2"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.1/transcribe-cpp-v26.8.1-x86_64-apple-darwin.tar.gz"
    sha256 "f81c089f10023e7485cbe743d6f6b2b5cfe93f913a04f45a0712ad246529188a"
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
