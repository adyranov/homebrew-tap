require_relative "../lib/metal_dist_install"

class AcestepCpp < Formula
  include MetalDistInstall

  desc "ACE-Step 1.5 music generation in C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/ServeurpersoCom/acestep.cpp"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.0/acestep-cpp-v26.8.0-arm64-apple-darwin.tar.gz"
    sha256 "be382eb208db6ab23b8b091c242f679752399558e351a4a6dbdb57c1cb31da83"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.0/acestep-cpp-v26.8.0-x86_64-apple-darwin.tar.gz"
    sha256 "4d3ccc149e7fb93770be96100354794ed733a90b03a70a0e24caa794710a42f3"
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
