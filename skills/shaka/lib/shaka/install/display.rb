# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module Shaka
  module Install
    # Labels managed copies in Codex without changing the portable skill name.
    module Display
      def self.write(root, version, source)
        path = File.join(root, 'skills/shaka/agents/openai.yaml')
        metadata = load(path)
        metadata['interface'] = interface(metadata, version, source)
        write_file(path, metadata)
      rescue Psych::Exception => e
        raise ArgumentError, "Invalid skill UI metadata: #{e.message}"
      end

      def self.write_file(path, metadata)
        directory = File.dirname(path)
        with_writable_directory(File.dirname(directory)) { FileUtils.mkdir_p(directory, mode: 0o755) }
        with_writable_directory(directory) do
          mode = File.exist?(path) ? File.stat(path).mode & 0o777 : 0o644
          File.chmod(mode | 0o200, path) if File.exist?(path)
          File.write(path, YAML.dump(metadata))
          File.chmod(mode, path)
        end
      end

      def self.with_writable_directory(directory)
        mode = File.stat(directory).mode & 0o777
        File.chmod(mode | 0o200, directory)
        yield
      ensure
        File.chmod(mode, directory) if mode
      end

      def self.load(path)
        metadata = File.exist?(path) ? YAML.safe_load_file(path) : {}
        raise ArgumentError, 'Skill UI metadata must be an object' unless metadata.is_a?(Hash)

        metadata
      end

      def self.interface(metadata, version, source)
        interface = metadata.fetch('interface', {})
        raise ArgumentError, 'Skill UI interface must be an object' unless interface.is_a?(Hash)

        interface['display_name'] = "Shaka #{version} (#{revision_label(source)})"
        interface
      end

      def self.revision_label(source)
        return source.fetch('revision')[0, 7] if source.fetch('kind') == 'revision'

        "dev #{source.fetch('content_sha256')[0, 7]}"
      end

      private_class_method :load, :write_file, :with_writable_directory, :interface, :revision_label
    end
  end
end
