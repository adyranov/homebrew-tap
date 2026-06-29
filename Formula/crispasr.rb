require_relative "../lib/metal_dist_install"

class Crispasr < Formula
  include MetalDistInstall

  desc "Unified multilingual ASR engine (Metal patch; fork of whisper.cpp)"
  homepage "https://github.com/CrispStrobe/CrispASR"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.2/crispasr-v26.6.2-arm64-apple-darwin.tar.gz"
    sha256 "c64467f77c7ef328e74f99f858c813935a5b4f5da03015269ac2bde87cfb24bf"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.2/crispasr-v26.6.2-x86_64-apple-darwin.tar.gz"
    sha256 "9312088728a8c622bb896946b37d74f8ee08fae020be40c7a0b64b1cfce294a7"
  end

  depends_on macos: :sonoma

  def caveats
    <<~EOS
      Model weights are not included. See CrispASR docs for GGUF models.
    EOS
  end

  test do
    assert_path_exists bin/"crispasr"
    out = shell_output("#{bin}/crispasr --help 2>&1")
    assert out.length > 20
  end
end
