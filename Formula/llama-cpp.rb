require_relative "../lib/metal_dist_install"

class LlamaCpp < Formula
  include MetalDistInstall

  desc "LLM inference in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.1/llama-cpp-v26.6.1-arm64-apple-darwin.tar.gz"
    sha256 "8fec75c8003383035471a253c7e0b31f998bbca51ddac20b953bb89405863b36"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.1/llama-cpp-v26.6.1-x86_64-apple-darwin.tar.gz"
    sha256 "4649f030b69462150d466a1b31297877500fed326457d87d0eaf1be781a05771"
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
