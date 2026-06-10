require_relative "../lib/metal_dist_install"

class StableDiffusionCpp < Formula
  include MetalDistInstall

  desc "Stable Diffusion inference in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.0/stable-diffusion-cpp-v26.6.0-arm64-apple-darwin.tar.gz"
    sha256 "64ba19814663e9f75faa027fe4a4219877fab84280784b2d842bd77785c9ccb4"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.0/stable-diffusion-cpp-v26.6.0-x86_64-apple-darwin.tar.gz"
    sha256 "c515742994249a5228b59a92d38762b32cf44694519452902084a9579ad46cbf"
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
