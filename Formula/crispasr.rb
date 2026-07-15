require_relative "../lib/metal_dist_install"

class Crispasr < Formula
  include MetalDistInstall

  desc "Unified multilingual ASR engine (Metal patch; fork of whisper.cpp)"
  homepage "https://github.com/CrispStrobe/CrispASR"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.2/crispasr-v26.7.2-arm64-apple-darwin.tar.gz"
    sha256 "81231b6b9a133b6dcd4dc006cb8d904102494952ce079c1337893f62f2ca68f2"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.2/crispasr-v26.7.2-x86_64-apple-darwin.tar.gz"
    sha256 "f6b8ca982e04c6794686d10efd1654b5a68890a51d179949ed894ae23a2fbb2e"
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
