# frozen_string_literal: true

require 'rbconfig'
require_relative 'source'
require_relative 'directory_safety'
require_relative '../executable_file'
require_relative 'refusal'

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

      # On Windows this starts the incoming shaka.rb with this revision's argv. Windows installs
      # therefore refuse an update that moves the files it names; test/shaka_command_test.rb says so.
      def verify_helper
        command = ExecutableFile.helper_command(File.join(@root, 'skills/shaka/scripts/shaka'))
        output, status = Open3.capture2e({ 'SHAKA_RUBY' => RbConfig.ruby }, *command, '--help', chdir: @root)
        raise ArgumentError, "Incoming Shaka helper failed verification: #{output.strip}" unless status.success?
      end

      def verify_modes
        entries = skill_paths.to_h { |path| [path, File.lstat(path)] }
        writable = entries.select { |_, entry| writable?(entry) }.keys
        foreign = entries.reject { |_, entry| trusted_owner?(entry) }.keys
        # Ownership comes first: chmod cannot fix a file another account owns.
        refuse_foreign(foreign) unless foreign.empty?
        refuse_writable(writable) unless writable.empty?
      end

      # A symlink's own mode bits grant nothing, and Linux reports every symlink as 0777.
      def writable?(entry) = !entry.symlink? && entry.mode.anybits?(0o022)

      def skills_root = File.join(@root, 'skills')

      def skill_paths
        [skills_root] + @names.flat_map { |name| [File.join(skills_root, name)] + @tree.listing(@root, name) }
      end

      def refuse_writable(paths)
        raise ArgumentError, Refusal.message('Installation skills are group or world writable',
                                             Refusal.paths(paths), Refusal.command('chmod', '-R', 'go-w', skills_root))
      end

      def refuse_foreign(paths)
        raise ArgumentError, Refusal.message(
          'Installation skills belong to another account', Refusal.paths(paths),
          Refusal.decide('whether to trust these files', 'to see their owners',
                         Refusal.command('ls', '-ln', *paths.first(Refusal::PATH_LIMIT)))
        )
      end
    end
  end
end
