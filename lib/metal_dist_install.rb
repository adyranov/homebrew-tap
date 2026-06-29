# typed: strict
# frozen_string_literal: true

# Shared install logic for the prebuilt, Metal-accelerated binary formulae in
# this tap (llama-cpp, whisper-cpp, stable-diffusion-cpp, acestep-cpp,
# crispasr, omnivoice-cpp).
# Artifacts may omit lib/ or include/, so install only the layout present.
module MetalDistInstall
  BIN_RENAMES = {}.freeze

  def install
    if (buildpath/"bin").directory?
      Dir["bin/*"].each do |src|
        name = File.basename(src)
        dest = self.class::BIN_RENAMES.fetch(name, name)
        bin.install src => dest
      end
    end
    lib.install Dir["lib/*"] if (buildpath/"lib").directory?
    include.install Dir["include/*"] if (buildpath/"include").directory?

    # Normalize each dylib's install name to its final keg path.
    Dir[lib/"*.dylib"].each do |dylib|
      system "install_name_tool", "-id", dylib.to_s, dylib.to_s
    end

    (Dir[bin/"*"] + Dir[lib/"*.dylib"]).each do |path|
      add_lib_rpath(Pathname(path))
    end
  end

  private

  def add_lib_rpath(path)
    return unless path.file?
    return unless mach_o?(path)

    rpaths = Utils.safe_popen_read("otool", "-l", path.to_s)
    return if rpaths.include?("path #{lib} ")

    system "install_name_tool", "-add_rpath", lib.to_s, path.to_s
  end

  def mach_o?(path)
    MachO.open(path.to_s)
    true
  rescue MachO::MachOBinaryError, MachO::NotAMachOError
    false
  end
end
