require_relative "../lib/metal_dist_install"

class OmnivoiceCpp < Formula
  include MetalDistInstall

  desc "OmniVoice text-to-speech in C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/ServeurpersoCom/omnivoice.cpp"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.0/omnivoice-cpp-v26.8.0-arm64-apple-darwin.tar.gz"
    sha256 "9c3a0474be5f6209bebe360d25252d05abf38665184f08077771fb2df48ed932"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.0/omnivoice-cpp-v26.8.0-x86_64-apple-darwin.tar.gz"
    sha256 "2f5faa7cc45c9c817cf1e995b81bebddafcff7a705ad2684e1d4408c7a586dbf"
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
