require_relative "../lib/metal_dist_install"

class Crispasr < Formula
  include MetalDistInstall

  desc "Unified multilingual ASR engine (Metal patch; fork of whisper.cpp)"
  homepage "https://github.com/CrispStrobe/CrispASR"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.1/crispasr-v26.7.1-arm64-apple-darwin.tar.gz"
    sha256 "926c911c581b3b7805259f7c4257c9bc8638ac756acf49f18ddddc1b23f06615"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.1/crispasr-v26.7.1-x86_64-apple-darwin.tar.gz"
    sha256 "a6b11e105b0222147c8bd3ddfe37fa4e35d0c9e8ee253fae2ea981998d0093e3"
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
