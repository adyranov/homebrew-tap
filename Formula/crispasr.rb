require_relative "../lib/metal_dist_install"

class Crispasr < Formula
  include MetalDistInstall

  desc "Unified multilingual ASR engine (Metal patch; fork of whisper.cpp)"
  homepage "https://github.com/CrispStrobe/CrispASR"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.1/crispasr-v26.6.1-arm64-apple-darwin.tar.gz"
    sha256 "10e362ff2f734fc9426b3f670e86dd98ba87e94f6c75bc8cd65c87b1dac384b0"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.1/crispasr-v26.6.1-x86_64-apple-darwin.tar.gz"
    sha256 "6ca40e43e5b1f8c05ce46a7392acfe2a46e151b3c1d16b99834baac9bd651cfd"
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
