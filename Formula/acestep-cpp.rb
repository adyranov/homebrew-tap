require_relative "../lib/metal_dist_install"

class AcestepCpp < Formula
  include MetalDistInstall

  desc "ACE-Step 1.5 music generation in C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/ServeurpersoCom/acestep.cpp"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.1/acestep-cpp-v26.8.1-arm64-apple-darwin.tar.gz"
    sha256 "7adee7706575a6d1ec95d62a3a821378ffe7d9979edef57bba1e926792920782"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.1/acestep-cpp-v26.8.1-x86_64-apple-darwin.tar.gz"
    sha256 "4a44c2c0fffbcc2340f7b2eec9fe8c5514e5228669f955bae789420b3e477b0c"
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
