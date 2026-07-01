require_relative "../lib/metal_dist_install"

class AcestepCpp < Formula
  include MetalDistInstall

  desc "ACE-Step 1.5 music generation in C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/ServeurpersoCom/acestep.cpp"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.0/acestep-cpp-v26.7.0-arm64-apple-darwin.tar.gz"
    sha256 "775d9b5abcee550ae386523bee72b786587933d8206c1836cf08bc14afd3fddd"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.0/acestep-cpp-v26.7.0-x86_64-apple-darwin.tar.gz"
    sha256 "aa91a7dc05ef43faa2299fce081798ed7f7d48665f596cd7afff6ec5fac9c349"
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
