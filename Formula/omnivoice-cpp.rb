require_relative "../lib/metal_dist_install"

class OmnivoiceCpp < Formula
  include MetalDistInstall

  desc "OmniVoice text-to-speech in C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/ServeurpersoCom/omnivoice.cpp"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.1/omnivoice-cpp-v26.8.1-arm64-apple-darwin.tar.gz"
    sha256 "187511e7c35feaca3709fb9587009287f2e014f26cc60a4a41928ebc95596c4c"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.1/omnivoice-cpp-v26.8.1-x86_64-apple-darwin.tar.gz"
    sha256 "4adc6851ad4c543e9bc75c33a161e5011bea06411d65cdda7554212946377d0e"
  end

  livecheck do
    url "https://github.com/adyranov/ggml-metal-dist"
    strategy :github_latest
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  depends_on macos: :sequoia

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
    assert_match(/usage:/i, out)
  end
end
