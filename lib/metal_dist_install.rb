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

    keg_rpath = lib.to_s

    # Collect regular (non-symlink) installed files for Mach-O processing.
    candidates = Dir[bin/"*", lib/"*.dylib"]
                 .map { |f| Pathname(f) }
                 .select(&:file?)
                 .reject(&:symlink?)

    # Phase 1: parse all candidates once, validate lib dylibs, gate.
    entries = [] # [[path, file], ...]
    lib_has_dylib = false

    candidates.each do |path|
      file = MachO.open(path.to_s)
      slices = file.is_a?(MachO::FatFile) ? file.machos : [file]

      if path.dirname == lib
        slices.each_with_index do |slice, idx|
          unless slice.dylib?
            detail = (slices.size > 1) ? " (slice #{idx}, arch #{slice.cputype})" : ""
            raise "expected MH_DYLIB at #{path}#{detail}, got #{slice.filetype}"
          end
        end
        lib_has_dylib = true
      end

      entries << [path, file]
    rescue MachO::NotAMachOError => e
      raise "invalid Mach-O (expected dylib) at #{path}: #{e.message}" if path.dirname == lib
      # bin/ may contain non-Mach-O files (scripts); skip.
    rescue MachO::MachOError => e
      raise "failed to parse #{path}: #{e.message}"
    end

    # Gate: no dylibs installed in lib/ → nothing to patch.
    return unless lib_has_dylib

    # Phase 2: apply dylib-id normalisation and keg rpath, one write per file.
    entries.each { |path, file| fixup_macho(path, file, keg_rpath) }
  end

  private

  def fixup_macho(path, file, keg_rpath)
    slices = file.is_a?(MachO::FatFile) ? file.machos : [file]

    # Verify each MH_DYLIB slice has LC_ID_DYLIB before reading dylib_id.
    if path.dirname == lib
      slices.each do |slice|
        next unless slice.dylib?
        raise "missing LC_ID_DYLIB in #{path}" unless slice.command(:LC_ID_DYLIB).first
      end
    end

    # Check each slice individually: FatFile aggregate accessors
    # (dylib_id, rpaths) delegate to the first slice or union, which
    # can miss slices that need changes.
    needs_id = path.dirname == lib && slices.any? { |s| s.dylib_id != path.to_s }
    needs_rpath = slices.any? { |s| s.rpaths.exclude?(keg_rpath) }

    return if !needs_id && !needs_rpath

    # Use the public FatFile API (change_dylib_id, add_rpath) which
    # handles slice iteration, error recovery, and raw-data repopulation.
    # For thin Mach-O files the same methods work directly.
    if file.is_a?(MachO::FatFile)
      file.change_dylib_id(path.to_s) if needs_id
      file.add_rpath(keg_rpath, strict: false) if needs_rpath
    else
      file.dylib_id = path.to_s if needs_id
      file.add_rpath(keg_rpath) if needs_rpath
    end

    file.write!
    MachO.codesign!(path.to_s)
  rescue MachO::DylibIdMissingError => e
    slice = e.macho_slice
    info = slice ? " (slice #{slice})" : ""
    raise "missing LC_ID_DYLIB in #{path}#{info}: #{e.message}"
  rescue MachO::RecoverableModificationError => e
    slice = e.macho_slice
    info = slice ? " (slice #{slice})" : ""
    raise "modification failed for #{path}#{info}: #{e.message}"
  rescue MachO::CodeSigningError => e
    raise "codesign failed for #{path}: #{e.message}"
  rescue MachO::MachOError => e
    raise "Mach-O operation failed for #{path}: #{e.message}"
  end
end
