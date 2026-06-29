require_relative "../lib/metal_dist_install"

class OmnivoiceCpp < Formula
  include MetalDistInstall

  desc "OmniVoice text-to-speech in C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/ServeurpersoCom/omnivoice.cpp"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.2/omnivoice-cpp-v26.6.2-arm64-apple-darwin.tar.gz"
    sha256 "9c81cab63d7751dcd69bc06b53c39768538e8c87636a2e76b5dacd7e2807bfc3"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.2/omnivoice-cpp-v26.6.2-x86_64-apple-darwin.tar.gz"
    sha256 "218ff9a1d5a0c8557e633d64a32e44366c6f2fb677d755110b3cf29e87e4c981"
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
