require_relative "../lib/metal_dist_install"

class AcestepCpp < Formula
  include MetalDistInstall

  desc "ACE-Step 1.5 music generation in C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/ServeurpersoCom/acestep.cpp"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.1/acestep-cpp-v26.7.1-arm64-apple-darwin.tar.gz"
    sha256 "5640f9eeee087edb9273769db6e1b1dcdb04a1fabbb5937ee08f642d78604fe5"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.1/acestep-cpp-v26.7.1-x86_64-apple-darwin.tar.gz"
    sha256 "93ecc3a717f9e34df8547d8416672445b1a9d600d6872c0cbde756bd2c4a7811"
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
