require_relative "../lib/metal_dist_install"

class StableDiffusionCpp < Formula
  include MetalDistInstall

  desc "Stable Diffusion inference in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.0/stable-diffusion-cpp-v26.7.0-arm64-apple-darwin.tar.gz"
    sha256 "b37851a8fcdb112b4076f9027700659f60b7605a9b1dcad688f1647f14f9d15b"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.0/stable-diffusion-cpp-v26.7.0-x86_64-apple-darwin.tar.gz"
    sha256 "ce189a94839de1d95e04b8582f5109144a35031eead44dbe6916b6a3b412986c"
  end

  depends_on macos: :sonoma

  def caveats
    <<~EOS
      Model weights are not included. See stable-diffusion.cpp docs for GGUF models.
    EOS
  end

  test do
    assert_path_exists bin/"sd-cli"
    out = shell_output("#{bin}/sd-cli --help 2>&1")
    assert out.length > 20
  end
end
