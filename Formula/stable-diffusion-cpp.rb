require_relative "../lib/metal_dist_install"

class StableDiffusionCpp < Formula
  include MetalDistInstall

  desc "Stable Diffusion inference in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.2/stable-diffusion-cpp-v26.7.2-arm64-apple-darwin.tar.gz"
    sha256 "0e51a7ae17649c33acc2d96c508bc1f2eede81eba1292c0ba1e331065f1b92c0"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.2/stable-diffusion-cpp-v26.7.2-x86_64-apple-darwin.tar.gz"
    sha256 "c831eacd4fa521719edbe591182c6371f080e9d2134d2514aa8d9871f39cf7f5"
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
