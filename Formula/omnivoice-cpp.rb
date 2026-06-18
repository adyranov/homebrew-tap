require_relative "../lib/metal_dist_install"

class OmnivoiceCpp < Formula
  include MetalDistInstall

  desc "OmniVoice text-to-speech in C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/ServeurpersoCom/omnivoice.cpp"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.1/omnivoice-cpp-v26.6.1-arm64-apple-darwin.tar.gz"
    sha256 "79fab017b5894eea01d66476ef77fb9347f8fd8c5b9d377133cf5b1ebbafd449"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.1/omnivoice-cpp-v26.6.1-x86_64-apple-darwin.tar.gz"
    sha256 "4b2ab9aa640852e0452ba3f40cbad27c73389ff953aeac5c55fe56c523a2ebb7"
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
