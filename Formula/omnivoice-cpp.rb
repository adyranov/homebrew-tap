require_relative "../lib/metal_dist_install"

class OmnivoiceCpp < Formula
  include MetalDistInstall

  desc "OmniVoice text-to-speech in C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/ServeurpersoCom/omnivoice.cpp"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.2/omnivoice-cpp-v26.7.2-arm64-apple-darwin.tar.gz"
    sha256 "5a6459d1213f9678d06e411cbc665ba4f4e20275a836df2815b2fc7c056d6d42"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.2/omnivoice-cpp-v26.7.2-x86_64-apple-darwin.tar.gz"
    sha256 "ad358739f639825c39f490d96568df6d28af511e04662be4f30cf5ce9eb3b9d3"
  end

  depends_on macos: :sonoma

  BIN_RENAMES = {
    "quantize"   => "omnivoice-quantize",
    "tts-server" => "omnivoice-tts-server",
  }.freeze

  def caveats
    <<~EOS
      Model weights are not included. See omnivoice.cpp docs for GGUF models.
      Utility binaries are installed with omnivoice- prefixes: omnivoice-quantize, omnivoice-tts-server.
    EOS
  end

  test do
    assert_path_exists bin/"omnivoice-tts"
    assert_path_exists bin/"omnivoice-quantize"
    out = shell_output("#{bin}/omnivoice-tts --help 2>&1")
    assert out.length > 20
  end
end
