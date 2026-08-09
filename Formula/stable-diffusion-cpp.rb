require_relative "../lib/metal_dist_install"

class StableDiffusionCpp < Formula
  include MetalDistInstall

  desc "Stable Diffusion inference in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.2/stable-diffusion-cpp-v26.8.2-arm64-apple-darwin.tar.gz"
    sha256 "f28f600841956d9b129958fc1a4fbeda0368eb13e96f0906fdaac2a2cfab3c95"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.2/stable-diffusion-cpp-v26.8.2-x86_64-apple-darwin.tar.gz"
    sha256 "7d559d17329956cfe3f779590908b5ba8c6dca90cb0405e1da617abdded921f7"
  end

  livecheck do
    url :homepage
    strategy :github_latest
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  depends_on macos: :sequoia

  def caveats
    <<~EOS
      Model weights are not included. See stable-diffusion.cpp docs for GGUF models.
    EOS
  end

  test do
    assert_path_exists bin/"sd-cli"
    out = shell_output("#{bin}/sd-cli --help 2>&1")
    assert_match(/usage:/i, out)
  end
end
