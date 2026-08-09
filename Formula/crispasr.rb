require_relative "../lib/metal_dist_install"

class Crispasr < Formula
  include MetalDistInstall

  desc "Unified multilingual ASR engine (Metal patch; fork of whisper.cpp)"
  homepage "https://github.com/CrispStrobe/CrispASR"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.2/crispasr-v26.8.2-arm64-apple-darwin.tar.gz"
    sha256 "d69b7ee4cef12767817a63ff1668b444ca0f7a3c9da0bd3af5559673e0d317f5"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.2/crispasr-v26.8.2-x86_64-apple-darwin.tar.gz"
    sha256 "000e0df9a09a84d255885c3f8f36db65a76eb27626458a433763b7f324b60efc"
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
