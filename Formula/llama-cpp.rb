require_relative "../lib/metal_dist_install"

class LlamaCpp < Formula
  include MetalDistInstall

  desc "LLM inference in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.2/llama-cpp-v26.7.2-arm64-apple-darwin.tar.gz"
    sha256 "1c05fa1262fda09fde44ab1d574b0970569cd8ababc37d9af3abea104050094a"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.2/llama-cpp-v26.7.2-x86_64-apple-darwin.tar.gz"
    sha256 "dcbda771b4e46c01bebe853170d8f3f20aff7cbb03ccbf36287ebc50e6005794"
  end

  depends_on macos: :sonoma
  depends_on "openssl@3"

  conflicts_with "llama.cpp", because: "both install llama-* binaries with embedded Metal-patched ggml"

  def caveats
    <<~EOS
      Embeds Metal-patched ggml (not the Homebrew ggml formula).
      Conflicts with official llama.cpp.
    EOS
  end

  test do
    assert_path_exists bin/"llama-cli"
    out = shell_output("#{bin}/llama-cli --help 2>&1")
    assert out.length > 20
  end
end
