require_relative "../lib/metal_dist_install"

class StableDiffusionCpp < Formula
  include MetalDistInstall

  desc "Stable Diffusion inference in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.1/stable-diffusion-cpp-v26.8.1-arm64-apple-darwin.tar.gz"
    sha256 "8045f3c68575c9a2f985a00782845a1c1010a4dba274b0ce2c3d157a57a904bf"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.1/stable-diffusion-cpp-v26.8.1-x86_64-apple-darwin.tar.gz"
    sha256 "e858eb38379dcf662192db7d87eabfb9d5794295215cadd40f549707f0df5e1d"
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
