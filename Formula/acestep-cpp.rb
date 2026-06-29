require_relative "../lib/metal_dist_install"

class AcestepCpp < Formula
  include MetalDistInstall

  desc "ACE-Step 1.5 music generation in C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/ServeurpersoCom/acestep.cpp"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.2/acestep-cpp-v26.6.2-arm64-apple-darwin.tar.gz"
    sha256 "48c09048c6fe74c00be54e2fadf21569208d487bd812b7172c64b9d388437007"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.2/acestep-cpp-v26.6.2-x86_64-apple-darwin.tar.gz"
    sha256 "d306fcabdd7762d03a577416f83578c18235d58f109a8fcd64d872492f6387e4"
  end

  depends_on macos: :sonoma

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
    assert out.length > 20
  end
end
