require_relative "../lib/metal_dist_install"

class StableDiffusionCpp < Formula
  include MetalDistInstall

  desc "Stable Diffusion inference in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.1/stable-diffusion-cpp-v26.6.1-arm64-apple-darwin.tar.gz"
    sha256 "26ff92d548c2eb1ca5f516144ff4579ae5b3cd2d7a9e0c34279479728443f86e"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.1/stable-diffusion-cpp-v26.6.1-x86_64-apple-darwin.tar.gz"
    sha256 "33132fc5623d1734e21d954f34fe3e787cff7cd3970c2918c91802e64f59bc32"
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
