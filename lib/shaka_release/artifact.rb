# frozen_string_literal: true

require 'rubygems/package'

module ShakaRelease
  # Compares the supplied gem's metadata, bytes and executable modes with the clean source.
  class Artifact
    METADATA = (Gem::Specification.attribute_names - %i[date rubygems_version]).freeze

    def initialize(root:, path:)
      @root = root
      @path = path
    end

    def check
      digest = Digest::SHA256.file(@path).hexdigest
      package = Gem::Package.new(@path)
      expected = Dir.chdir(@root) { Gem::Specification.load('shaka.gemspec') }
      raise Shaka::Error, 'Cannot load source gemspec' unless expected

      check_metadata(package.spec, expected)
      check_contents(package, expected)
      raise Shaka::Error, 'Gem changed during preflight' unless digest == Digest::SHA256.file(@path).hexdigest

      { 'version' => expected.version.to_s, 'gem_sha256' => digest, 'files' => package.contents.size }
    end

    private

    def check_metadata(actual, expected)
      matches = METADATA.all? { |attribute| actual.public_send(attribute) == expected.public_send(attribute) }
      raise Shaka::Error, 'Gem metadata differs from source gemspec' unless matches && actual.name == 'shaka'
    end

    def check_contents(package, expected)
      paths = expected.files.select { |path| File.file?(File.join(@root, path)) }.sort
      raise Shaka::Error, 'Gem package file list differs from source' unless package.contents.sort == paths

      entries = committed_entries
      File.open(@path, 'rb') do |archive|
        Gem::Package::TarReader.new(archive).each do |entry|
          check_payload(entry, entries) if entry.full_name == 'data.tar.gz'
        end
      end
    end

    def check_payload(entry, entries)
      Zlib::GzipReader.wrap(entry) do |gzip|
        Gem::Package::TarReader.new(gzip).each { |file| check_file(file, entries[file.full_name]) }
      end
    end

    def committed_entries
      output, error, status = Open3.capture3(Shaka::WorkflowVersion::GIT_ENVIRONMENT,
                                             'git', '-C', @root, 'ls-tree', '-rz', 'HEAD')
      raise Shaka::Error, "Cannot read committed source: #{error}" unless status.success?

      output.split("\0").to_h do |entry|
        metadata, path = entry.split("\t", 2)
        mode, _type, sha = metadata.split
        [path, [mode, sha]]
      end
    end

    def check_file(file, entry)
      raise Shaka::Error, "File absent from committed source: #{file.full_name}" unless entry

      mode, sha = entry
      bytes = file.read
      # Git records owner execution; group and other permissions can vary with umask.
      valid = file.file? && %w[100644 100755].include?(mode) &&
              Digest::SHA1.hexdigest("blob #{bytes.bytesize}\0#{bytes}") == sha &&
              file.header.mode.anybits?(0o100) == (mode == '100755')
      raise Shaka::Error, "Gem package content differs from committed source: #{file.full_name}" unless valid
    end
  end
end
