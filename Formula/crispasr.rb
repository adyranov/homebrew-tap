require_relative "../lib/metal_dist_install"

class Crispasr < Formula
  include MetalDistInstall

  desc "Unified multilingual ASR engine (Metal patch; fork of whisper.cpp)"
  homepage "https://github.com/CrispStrobe/CrispASR"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.0/crispasr-v26.8.0-arm64-apple-darwin.tar.gz"
    sha256 "68f17b475b291224f5c14fc067496485007ddfc86e9de705fa6f2f49b2b7c527"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.0/crispasr-v26.8.0-x86_64-apple-darwin.tar.gz"
    sha256 "5c7ef982b9f7f17ed5fe59e92f9db712e8530062d57b3fae7cdf24f9b81657f5"
  end

  livecheck do
    url "https://github.com/adyranov/ggml-metal-dist"
    strategy :github_latest
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  depends_on macos: :sequoia

  def caveats
    <<~EOS
      Model weights are not included. See CrispASR docs for GGUF models.
    EOS
  end

  test do
    assert_path_exists bin/"crispasr"
    out = shell_output("#{bin}/crispasr --help 2>&1")
    assert_match(/usage:/i, out)
  end
end
