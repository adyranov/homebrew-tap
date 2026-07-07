require_relative "../lib/metal_dist_install"

class LlamaCpp < Formula
  include MetalDistInstall

  desc "LLM inference in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.1/llama-cpp-v26.7.0-arm64-apple-darwin.tar.gz"
    sha256 "6df2e98fa398a4301828475092b0510558883bfec4d343d699b21b81a04d6047"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.1/llama-cpp-v26.7.0-x86_64-apple-darwin.tar.gz"
    sha256 "3100f0ec5de1f27e4d44b00c04591acd6fff68538c7536a9236a9437307b9350"
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
