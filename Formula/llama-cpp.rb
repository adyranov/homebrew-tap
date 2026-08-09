require_relative "../lib/metal_dist_install"

class LlamaCpp < Formula
  include MetalDistInstall

  desc "LLM inference in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.2/llama-cpp-v26.8.2-arm64-apple-darwin.tar.gz"
    sha256 "b1ba02cd4c241abe538911052eab3c5f2cf2918f8cfad59267868a384051dab5"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.2/llama-cpp-v26.8.2-x86_64-apple-darwin.tar.gz"
    sha256 "449b7f12b0cc46f0fa3266aa4b7b648fdfd7d772b9da9646ef0c2b1a3dd9dc79"
  end

  livecheck do
    url :homepage
    strategy :github_latest
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  depends_on macos: :sequoia
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
    assert_match(/usage/i, out)
  end
end
