require_relative "../lib/metal_dist_install"

class AcestepCpp < Formula
  include MetalDistInstall

  desc "ACE-Step 1.5 music generation in C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/ServeurpersoCom/acestep.cpp"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.2/acestep-cpp-v26.7.2-arm64-apple-darwin.tar.gz"
    sha256 "95f5c5b9b12f8a5d14aa5ae79a80a42786ff3b61fd2fce0f6cc76965bda36acd"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.2/acestep-cpp-v26.7.2-x86_64-apple-darwin.tar.gz"
    sha256 "9d54284b3e743b9960565b2ad201410308755d0f72120c62c80b2bdeccb230cc"
  end

  livecheck do
    url "https://github.com/adyranov/ggml-metal-dist"
    strategy :github_latest
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  depends_on macos: :sequoia

  BIN_RENAMES = {
    "mp3-codec"    => "ace-mp3-codec",
    "neural-codec" => "ace-neural-codec",
    "quantize"     => "ace-quantize",
  }.freeze

  def caveats
    <<~EOS
      Model weights are not included. See acestep.cpp docs for GGUF models.
      Utility binaries are installed with ace- prefixes: ace-quantize, ace-mp3-codec, ace-neural-codec.
    EOS
  end

  test do
    assert_path_exists bin/"ace-lm"
    assert_path_exists bin/"ace-quantize"
    out = shell_output("#{bin}/ace-lm --help 2>&1")
    assert_match(/usage:/i, out)
  end
end
