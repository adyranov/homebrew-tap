require_relative "../lib/metal_dist_install"

class OmnivoiceCpp < Formula
  include MetalDistInstall

  desc "OmniVoice text-to-speech in C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/ServeurpersoCom/omnivoice.cpp"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.2/omnivoice-cpp-v26.8.2-arm64-apple-darwin.tar.gz"
    sha256 "78cf0b57fd99b286eab6f1cd7b372a0483a6b925515681d66f09b40c1aa5a3a0"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.2/omnivoice-cpp-v26.8.2-x86_64-apple-darwin.tar.gz"
    sha256 "0df8e12587d61c27c78e0bd0692a2a1ec1d78afb48622ffccd13f64d3e883d9a"
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
