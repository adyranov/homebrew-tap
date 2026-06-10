require_relative "../lib/metal_dist_install"

class ParakeetCpp < Formula
  include MetalDistInstall

  desc "NVIDIA Parakeet speech recognition in C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/mudler/parakeet.cpp"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.0/parakeet-cpp-v26.6.0-arm64-apple-darwin.tar.gz"
    sha256 "e8420060aa71080a8061465a4dd14ae0bd457def500c8a8897a3806453172102"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.0/parakeet-cpp-v26.6.0-x86_64-apple-darwin.tar.gz"
    sha256 "687756cbcf5e697bb76cc7665256dd92818a0f63759592259266c84ac1d11f46"
  end

  depends_on macos: :sonoma

  def caveats
    <<~EOS
      Model weights are not included. See parakeet.cpp docs for GGUF models.
    EOS
  end

  test do
    assert_path_exists bin/"parakeet-cli"
    out = shell_output("#{bin}/parakeet-cli --help 2>&1", 2)
    assert_match "parakeet-cli transcribe", out
  end
end
