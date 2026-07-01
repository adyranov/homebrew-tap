require_relative "../lib/metal_dist_install"

class Crispasr < Formula
  include MetalDistInstall

  desc "Unified multilingual ASR engine (Metal patch; fork of whisper.cpp)"
  homepage "https://github.com/CrispStrobe/CrispASR"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.0/crispasr-v26.7.0-arm64-apple-darwin.tar.gz"
    sha256 "cac36acca901526c2ba60ab1c3309ce0e08c63e830c8dae3fa3744fd7b104e02"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.0/crispasr-v26.7.0-x86_64-apple-darwin.tar.gz"
    sha256 "d5bc815f63e894144e9e6fa0917314f2541bde9ea816d5769da34a92eb1a33a4"
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
