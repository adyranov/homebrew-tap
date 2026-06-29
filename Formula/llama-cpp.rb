require_relative "../lib/metal_dist_install"

class LlamaCpp < Formula
  include MetalDistInstall

  desc "LLM inference in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.2/llama-cpp-v26.6.2-arm64-apple-darwin.tar.gz"
    sha256 "7289dfd5fd0efb08c551b38792b7af3d799af80d6342707ca30a665bfae342fd"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.2/llama-cpp-v26.6.2-x86_64-apple-darwin.tar.gz"
    sha256 "13598506b93abfdf5ec140d6b04cb018125960e8bbff3a331554e10c16cc0830"
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
