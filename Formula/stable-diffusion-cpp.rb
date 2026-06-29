require_relative "../lib/metal_dist_install"

class StableDiffusionCpp < Formula
  include MetalDistInstall

  desc "Stable Diffusion inference in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.2/stable-diffusion-cpp-v26.6.2-arm64-apple-darwin.tar.gz"
    sha256 "9d44df8b6b907ea53e7fb25e9189c9c31323b8dfffb95f886558646a3efaa28a"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.2/stable-diffusion-cpp-v26.6.2-x86_64-apple-darwin.tar.gz"
    sha256 "77e348c41aa4f500772a811f910b7d6b4cc6ea05e3c1b7cec93aec5fec87e8df"
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
