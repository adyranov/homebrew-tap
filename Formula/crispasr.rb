require_relative "../lib/metal_dist_install"

class Crispasr < Formula
  include MetalDistInstall

  desc "Unified multilingual ASR engine (Metal patch; fork of whisper.cpp)"
  homepage "https://github.com/CrispStrobe/CrispASR"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.1/crispasr-v26.8.1-arm64-apple-darwin.tar.gz"
    sha256 "2e68c863895be666c6e47ceeb1ada286891a8cc41442790a9d89e79081187e6a"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.1/crispasr-v26.8.1-x86_64-apple-darwin.tar.gz"
    sha256 "e0ab19107a33e7c194c4733bbc6af70a3874f670e327332bedfddb0dcb9092e2"
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
