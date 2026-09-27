# frozen_string_literal: true

module Shaka
  class Seam
    class Upgrader
      # Apply operations for the layout upgrade.
      module Apply
        private

        def apply(plan, report)
          blockers = report.fetch('blockers')
          raise Error, "Upgrade blocked: #{blockers.join('; ')}" unless blockers.empty?

          check_reviewed_digest!(report)
          return emit_apply(report, 'already_upgraded') if report['status'] == 'already_upgraded'

          journal = upgrade_journal(plan, report)
          preflight_permissions!(journal.fetch('original').keys)
          write_journal(journal)
          execute_upgrade(journal)
          emit_apply(report, 'applied')
        end

        def check_reviewed_digest!(report)
          return if @options[:digest] == report.fetch('digest')

          raise Error, 'Upgrade inputs changed; run a fresh preview'
        end

        def emit_apply(report, status)
          puts JSON.generate(report.merge('mode' => 'apply', 'status' => status))
          0
        end

        def upgrade_journal(plan, report)
          original = plan.original_states
          desired = plan.desired_states
          temporary = original.keys.map { |path| "#{path}.shaka-upgrade-tmp" }
          { 'version' => 1, 'original' => original, 'desired' => desired,
            'digest' => report.fetch('digest'), 'temporary' => temporary }
        end

        def execute_upgrade(journal)
          write_desired(journal)
          Configuration.worktree(root: @root)
          File.delete(journal_path)
        rescue StandardError => e
          begin
            restore(journal)
          rescue StandardError => recovery_error
            raise Error, "Apply failed: #{e.message}; recovery needed: #{recovery_error.message}. Run --recover."
          end
          raise Error, "Apply failed and was restored: #{e.message}"
        end

        def preflight_permissions!(paths)
          paths.each do |relative|
            preflight_path(relative)
            preflight_temporary!(relative)
          end
          raise Error, "Permission denied for #{journal_path}" unless File.writable?(File.dirname(journal_path))
        end

        def preflight_temporary!(relative)
          temporary = File.join(@root, "#{relative}.shaka-upgrade-tmp")
          return unless File.exist?(temporary) || File.symlink?(temporary)

          raise Error, "Existing upgrade temporary file: #{temporary}; preserve or remove it before retrying"
        end

        def preflight_path(relative)
          absolute = File.join(@root, relative)
          parent = existing_parent(absolute)
          unless File.writable?(parent)
            raise Error,
                  "Permission denied for #{relative}: parent #{parent} is not writable"
          end
          return unless File.exist?(absolute) || File.symlink?(absolute)
          return unless File.directory?(absolute) && !File.symlink?(absolute)

          raise Error, "#{relative}: expected a file or symlink"
        end
      end
    end
  end
end
