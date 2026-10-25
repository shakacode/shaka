# frozen_string_literal: true

require 'rubygems/package'
require 'tmpdir'

module ShakaRelease
  # Compares the supplied gem's metadata, bytes and executable modes with the clean source.
  class Artifact
    METADATA = %i[name version platform summary authors licenses metadata required_ruby_version
                  required_rubygems_version dependencies executables bindir require_paths extensions].freeze

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
      Dir.mktmpdir('shaka-release-package') do |directory|
        package.extract_files(directory)
        paths.each { |path| check_file(File.join(directory, path), path, entries[path]) }
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

    def check_file(packaged, path, entry)
      raise Shaka::Error, "File absent from committed source: #{path}" unless entry

      mode, sha = entry
      bytes = File.binread(packaged)
      valid = !File.symlink?(packaged) && %w[100644 100755].include?(mode) &&
              Digest::SHA1.hexdigest("blob #{bytes.bytesize}\0#{bytes}") == sha &&
              File.stat(packaged).mode & 0o111 == (mode == '100755' ? 0o111 : 0)
      raise Shaka::Error, "Gem package content differs from committed source: #{path}" unless valid
    end
  end
end
