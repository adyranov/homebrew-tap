require_relative "../lib/metal_dist_install"

class AcestepCpp < Formula
  include MetalDistInstall

  desc "ACE-Step 1.5 music generation in C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/ServeurpersoCom/acestep.cpp"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.2/acestep-cpp-v26.8.2-arm64-apple-darwin.tar.gz"
    sha256 "9a802182e7d0a43f8747f9dcf5ea01054a3e24c266cbb8c15eeca46564fc518c"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.2/acestep-cpp-v26.8.2-x86_64-apple-darwin.tar.gz"
    sha256 "f40fba2a919704e85fc89c26adf4f64beb858e9561f965f33bdc10984d266aa0"
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
