require_relative "../lib/metal_dist_install"

class LlamaCpp < Formula
  include MetalDistInstall

  desc "LLM inference in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.2/llama-cpp-v26.7.1-arm64-apple-darwin.tar.gz"
    sha256 "63d072c924c83bbe400764cd0e129b42f1517a1e1ed16259078c8c6917e53f00"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.2/llama-cpp-v26.7.1-x86_64-apple-darwin.tar.gz"
    sha256 "96d17d5ef18547e31d4dfe3d23142a0fa0ede0b4e1092519359c0454c4ad1991"
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
