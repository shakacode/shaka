# frozen_string_literal: true

module Shaka
  class Seam
    class Upgrader
      # Recovery operations for the layout upgrade.
      module Recovery
        private

        def recover
          if !File.file?(journal_path) || File.symlink?(journal_path)
            raise Error, "No regular interrupted upgrade journal at #{JOURNAL}"
          end

          journal = JSON.parse(File.read(journal_path))
          validate_journal!(journal)

          restore(journal)
          puts JSON.generate('mode' => 'recover', 'status' => 'restored',
                             'paths' => journal.fetch('original').keys.sort)
          0
        end

        def restore(journal)
          original = journal.fetch('original')
          verify_recovery_state!(journal)
          journal.fetch('temporary').each { |relative| remove_state(File.join(@root, relative)) }
          original.sort.each { |path, state| write_state(path, state) }
          File.delete(journal_path)
          cleanup_empty_directories
        end

        def verify_recovery_state!(journal)
          journal.fetch('original').each do |path, before|
            current = UpgradePlan.new(@root).snapshot(path)
            next if current == before || current == journal.fetch('desired').fetch(path)

            raise Error, "#{path} changed after interruption; preserve that edit and repair manually"
          end
        end

        def validate_journal!(journal)
          raise Error, "Unsupported upgrade journal at #{JOURNAL}" unless journal['version'] == 1

          original = journal.fetch('original')
          desired = journal.fetch('desired')
          raise Error, 'Upgrade journal path sets differ' unless original.keys.sort == desired.keys.sort

          original.each_key { |path| safe_recovery_path!(path) }
          validate_temporary_paths!(journal, original.keys)
        end

        def validate_temporary_paths!(journal, paths)
          expected_temps = paths.map { |path| "#{path}.shaka-upgrade-tmp" }.sort
          raise Error, 'Upgrade journal temporary paths differ' unless journal.fetch('temporary').sort == expected_temps
        end

        def safe_recovery_path!(relative)
          absolute = File.expand_path(relative, @root)
          parts = relative.split('/')
          unsafe = relative.start_with?('/') || parts.include?('..') || parts.include?('.git') ||
                   !absolute.start_with?("#{@root}/")
          raise Error, "Unsafe upgrade journal path: #{relative}" if unsafe

          existing_parent(absolute)
        end
      end
    end
  end
end
