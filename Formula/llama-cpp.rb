require_relative "../lib/metal_dist_install"

class LlamaCpp < Formula
  include MetalDistInstall

  desc "LLM inference in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.0/llama-cpp-v26.6.0-arm64-apple-darwin.tar.gz"
    sha256 "53ba4edb0c70d4ed9ed67d22393465a60766ac124fc7acbdf9b348d6ee21a196"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.0/llama-cpp-v26.6.0-x86_64-apple-darwin.tar.gz"
    sha256 "a1cb80ae314b590f16d178b36a93ba111d5f646fff3801b3b89ed3870ee7a1f6"
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
