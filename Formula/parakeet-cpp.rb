require_relative "../lib/metal_dist_install"

class ParakeetCpp < Formula
  include MetalDistInstall

  desc "NVIDIA Parakeet speech recognition in C++ (Metal patch for Intel/Radeon Macs)"
  homepage "https://github.com/mudler/parakeet.cpp"
  license "MIT"

  if Hardware::CPU.arm?
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.1/parakeet-cpp-v26.6.1-arm64-apple-darwin.tar.gz"
    sha256 "5fa307e44344cd56d3e49a095a30eb8ebc6d3dc6213f2a115649afe3fe23e1b4"
  else
    url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.1/parakeet-cpp-v26.6.1-x86_64-apple-darwin.tar.gz"
    sha256 "a35337764e73ff768a93ea69ae2b298e902974f598365c6f2bb39cfee60e3b4a"
  end

  depends_on macos: :sonoma

  conflicts_with "adyranov/tap/whisper-cpp", because: "whisper-cpp bundles parakeet-cli and parakeet-quantize"

  def caveats
    <<~EOS
      Model weights are not included. See parakeet.cpp docs for GGUF models.
      Conflicts with whisper-cpp, which bundles parakeet-cli since v26.6.1.
    EOS
  end

  test do
    assert_path_exists bin/"parakeet-cli"
    out = shell_output("#{bin}/parakeet-cli --help 2>&1", 2)
    assert_match "parakeet-cli transcribe", out
  end
end
