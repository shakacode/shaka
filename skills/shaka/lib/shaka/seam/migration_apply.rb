# frozen_string_literal: true

require 'open3'
require 'yaml'
require_relative 'initializer'
require_relative 'initializer_destination'
require_relative 'initializer_readme'

module Shaka
  class Seam
    # Writes migrate destinations only after every preflight succeeds.
    module MigrationApply
      include InitializerDestination
      include InitializerReadme

      private

      def apply(report)
        raise Error, "blocking fields: #{report.fetch('blocking').join(', ')}" unless report.fetch('blocking').empty?

        files = generated_files(report)
        preflight_directories
        preflight_migration_files(files)
        created = write_migration_files(files)
        verify_candidate(created)
        CheckReport.emit(report)
      end

      def generated_files(report)
        {
          File.join(root, Migrator::CONTRACT) => contract_source(report.fetch('established')),
          File.join(root, Initializer::POINTER_PATH) => readme_source
        }
      end

      def contract_source(established)
        "# #{Migrator::MARKER}\n#{YAML.dump(typed_contract(established))}"
      end

      def typed_contract(established)
        {
          'version' => 1,
          'base_branch' => established['base_branch'],
          'review' => established.fetch('review'),
          'merge' => established.fetch('merge'),
          'branches' => established['branches'],
          'recovery' => established['recovery'],
          'repo_prefix' => established['repo_prefix'],
          'plan' => established['plan']
        }.compact
      end

      def preflight_migration_files(files)
        files.each do |path, content|
          next unless File.exist?(path) || File.symlink?(path)
          next if contract_replaceable?(path)
          next if matching_destination?(path, content)

          raise Error, "Refusing existing destination: #{path.delete_prefix("#{root}/")}"
        end
      end

      def contract_replaceable?(path)
        path == File.join(root, Migrator::CONTRACT) && File.file?(path) && !File.symlink?(path) &&
          File.read(path) == @source
      end

      def write_migration_files(files)
        created = []
        replaced = false
        files.each { |path, content| persist(path, content, created) { replaced = true } }
        created
      rescue StandardError
        rollback_created(created)
        restore_contract if replaced
        raise
      end

      def persist(path, content, created)
        if contract_replaceable?(path)
          replace_contract(path, content)
          yield
          return
        end
        return if File.file?(path)

        write_new_file(path, content)
        created << path
      end

      def replace_contract(path, content)
        File.open(path, File::WRONLY | File::TRUNC) { |file| file.write(content) }
        File.chmod(destination_mode(path), path)
      end

      def verify_candidate(created)
        output, error, status = Open3.capture3(shaka_command, 'seam', 'check', '--root', root, '--local')
        return if status.success?

        undo_apply(created)
        detail = error.strip.empty? ? output.strip : error.strip
        raise Error, "candidate seam check failed: #{detail}"
      end

      def undo_apply(created)
        rollback_created(created)
        restore_contract if contract_changed?
      end

      def contract_changed?
        path = File.join(root, Migrator::CONTRACT)
        File.file?(path) && File.read(path) != @source
      end

      def shaka_command = File.expand_path('../../../scripts/shaka', __dir__)

      def generated_by = 'shaka seam migrate'

      def rollback_created(created)
        created.each { |path| File.delete(path) if File.file?(path) }
      end

      def restore_contract
        File.open(File.join(root, Migrator::CONTRACT), File::WRONLY | File::TRUNC) { |file| file.write(@source) }
      end
    end
  end
end
