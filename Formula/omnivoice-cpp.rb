require_relative "../lib/metal_dist_install"

class OmnivoiceCpp < Formula
  include MetalDistInstall

  desc "OmniVoice text-to-speech in C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/ServeurpersoCom/omnivoice.cpp"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.0/omnivoice-cpp-v26.7.0-arm64-apple-darwin.tar.gz"
    sha256 "aec1b03d5f7fdf9f886d83b25d5bce59aade5c2029c45bf3e0680b6340a6386b"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.0/omnivoice-cpp-v26.7.0-x86_64-apple-darwin.tar.gz"
    sha256 "bb416c564998c1c643596739fe96885b029de048eabf89b327e7fe70a570bdda"
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
