require_relative "../lib/metal_dist_install"

class OmnivoiceCpp < Formula
  include MetalDistInstall

  desc "OmniVoice text-to-speech in C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/ServeurpersoCom/omnivoice.cpp"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.1/omnivoice-cpp-v26.7.1-arm64-apple-darwin.tar.gz"
    sha256 "efe7ad406c3bcf94971bd45e5c389a50ef38d33c5cdd33550fa8f20b8431735f"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.1/omnivoice-cpp-v26.7.1-x86_64-apple-darwin.tar.gz"
    sha256 "ac2c1f336e4e2c29abfb49a5a63c71567982cba6151248dd0e1c851dcd652fc9"
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
