require_relative "../lib/metal_dist_install"

class AcestepCpp < Formula
  include MetalDistInstall

  desc "ACE-Step 1.5 music generation in C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/ServeurpersoCom/acestep.cpp"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.1/acestep-cpp-v26.6.1-arm64-apple-darwin.tar.gz"
    sha256 "e0a031ceea1cbcd07773963f42785d9c1ac255c5305b9d13c7374f0687a760c9"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.1/acestep-cpp-v26.6.1-x86_64-apple-darwin.tar.gz"
    sha256 "ceaf1d8d23cc7f52b70efae8856bc922140a12983dc474b88bf56b1cb9b175cd"
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
