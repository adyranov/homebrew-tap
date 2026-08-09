require_relative "../lib/metal_dist_install"

class LlamaCpp < Formula
  include MetalDistInstall

  desc "LLM inference in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.1/llama-cpp-v26.8.1-arm64-apple-darwin.tar.gz"
    sha256 "04328d4690b5229a5d660d734b1009f7eaaff36a6c5923f8244b6d1505b87374"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.1/llama-cpp-v26.8.1-x86_64-apple-darwin.tar.gz"
    sha256 "9f72b3f93e8a390a0365027c9d7d91c62678e180dff65ea76bd0f0389d123bcf"
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
