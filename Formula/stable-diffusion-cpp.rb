require_relative "../lib/metal_dist_install"

class StableDiffusionCpp < Formula
  include MetalDistInstall

  desc "Stable Diffusion inference in C/C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/adyranov/ggml-metal-dist"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.1/stable-diffusion-cpp-v26.7.1-arm64-apple-darwin.tar.gz"
    sha256 "445d2fdc9f110db2181d159fc20d155c70d8be75e0292429ff20be6aabc403bc"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.1/stable-diffusion-cpp-v26.7.1-x86_64-apple-darwin.tar.gz"
    sha256 "89ed960a16f8e2c1c3eb532b7ce406d15173bd26bc5048c2e2c5096bdff21d74"
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
