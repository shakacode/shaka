# frozen_string_literal: true

require 'rbconfig'
require_relative 'source'
require_relative 'directory_safety'

module Shaka
  module Install
    # Direct links require an exact revision and protected files, not normalized copies.
    class DirectSource < Source
      include DirectorySafety

      def identity(hash)
        verify_modes
        verify_helper
        data = super
        raise ArgumentError, 'Installation files differ from the checkout revision' unless data['kind'] == 'revision'

        { 'schema_version' => 1, 'package_id' => nil, 'version' => version, 'skills' => @names, 'source' => data }
      end

      private

      def verify_helper
        output, status = Open3.capture2e({ 'SHAKA_RUBY' => RbConfig.ruby },
                                         File.join(@root, 'skills/shaka/scripts/shaka'), '--help', chdir: @root)
        raise ArgumentError, "Incoming Shaka helper failed verification: #{output.strip}" unless status.success?
      end

      def verify_modes
        paths = @names.flat_map { |name| [File.join(@root, 'skills', name)] + @tree.entries(@root, name) }
        paths << File.join(@root, 'skills')
        raise ArgumentError, 'Installation skills have unsafe ownership or are group or world writable' if
          paths.any? do |path|
            entry = File.lstat(path)
            entry.mode.anybits?(0o022) || !trusted_owner?(entry)
          end
      end
    end
  end
end
