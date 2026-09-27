# frozen_string_literal: true

module Shaka
  class Seam
    class Upgrader
      # Apply operations for the layout upgrade.
      module Apply
        private

        def apply(_plan, report)
          blockers = report.fetch('blockers')
          raise Error, "Upgrade blocked: #{blockers.join('; ')}" unless blockers.empty?
          return emit_apply(report, 'already_upgraded') if report['status'] == 'already_upgraded'

          fresh = recheck_plan(report)
          journal = upgrade_journal(fresh, report)
          preflight_permissions!(journal.fetch('original').keys)
          write_journal(journal)
          execute_upgrade(journal)
          emit_apply(report, 'applied')
        end

        def emit_apply(report, status)
          puts JSON.generate(report.merge('mode' => 'apply', 'status' => status))
          0
        end

        def recheck_plan(report)
          fresh = UpgradePlan.new(@root)
          current = fresh.build
          return fresh if current['digest'] == report['digest'] && current['blockers'].empty?

          raise Error, 'Upgrade inputs changed during preflight; run a fresh preview'
        end

        def upgrade_journal(fresh, report)
          original = fresh.original_states
          desired = fresh.desired_states
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
          paths.each { |relative| preflight_path(relative) }
          raise Error, "Permission denied for #{JOURNAL}" unless File.writable?(File.dirname(journal_path))
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
