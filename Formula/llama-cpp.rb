require_relative "../lib/metal_dist_install"

class LlamaCpp < Formula
  include MetalDistInstall

  desc "LLM inference in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.0/llama-cpp-v26.8.0-arm64-apple-darwin.tar.gz"
    sha256 "464a4c6c9df54fd41c2b56c67a6db6a8f29852662a33691dddaa25d6ad78f8af"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.0/llama-cpp-v26.8.0-x86_64-apple-darwin.tar.gz"
    sha256 "aeb2b557f2d49f4e5d85cdb385263fdb5d6f2a7dd725f66db12c40775d249730"
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
