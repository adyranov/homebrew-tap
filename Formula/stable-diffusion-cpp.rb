require_relative "../lib/metal_dist_install"

class StableDiffusionCpp < Formula
  include MetalDistInstall

  desc "Stable Diffusion inference in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.0/stable-diffusion-cpp-v26.8.0-arm64-apple-darwin.tar.gz"
    sha256 "81b78c377c176b3f1f18e12c2a65b01f239f72526adea5f31226009fb1ee9bdc"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.8.0/stable-diffusion-cpp-v26.8.0-x86_64-apple-darwin.tar.gz"
    sha256 "a75bc3c750569bffce9e11053ead98b1ad36232eb244a9763ba1534220311820"
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
