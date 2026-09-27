# frozen_string_literal: true

module Shaka
  class Seam
    class UpgradePlan
      # Tracked reference inventory and checkout overlap checks.
      module References
        private

        def scan_references
          moved = @moves.map { |item| item.fetch('from') }
          tracked_paths.each { |path| scan_reference(path) unless moved.include?(path) }
        end

        def tracked_paths
          output, error, status = Open3.capture3('git', '-C', @root, 'ls-files', '-z')
          raise Error, "Cannot inventory tracked references: #{error.strip}" unless status.success?

          output.split("\0").sort
        end

        def scan_reference(path)
          text = reference_text(path)
          return unless text

          keys = reference_mapping.keys.select { |old| text.include?(old) }
          return if keys.empty?

          @references << { 'path' => path, 'kind' => reference_kind(path), 'paths' => keys }
          handle_reference(path, text, keys)
        end

        def reference_text(path)
          return unless snapshot(path)['type'] == 'file'

          text = File.binread(File.join(@root, path)).force_encoding(Encoding::UTF_8)
          text if text.valid_encoding?
        end

        def handle_reference(path, text, keys)
          return if path.match?(HISTORICAL)
          return block_executable_reference(path) if text.start_with?('#!') && !path.start_with?('.github/')

          replace_reference(path, text, reference_mapping.slice(*keys))
        end

        def reference_kind(path)
          return 'historical' if path.match?(HISTORICAL)
          return 'tracked CI' if path.start_with?('.github/')

          'repository guidance or executable reference'
        end

        def block_executable_reference(path)
          @blockers << "#{path}: executable old-path reference needs explicit repair"
        end

        def replace_reference(path, text, replacements)
          updated = replacements.reduce(text) { |result, (old, new_path)| result.gsub(old, new_path) }
          source = snapshot(path)
          @changes << { from: path, to: path, after: source.merge('data' => [updated.b].pack('m0')) }
        end

        def reference_mapping
          { PATHS::CONTRACT => PATHS::NEW_CONTRACT,
            PATHS::REPOSITORY_ALLOWLIST => PATHS::NEW_REPOSITORY_ALLOWLIST }.merge(
              command_paths.to_h { |old| [old, old.sub(PATHS::COMMAND_DIRECTORY, PATHS::NEW_COMMAND_DIRECTORY)] }
            )
        end

        def dirty_overlap
          (git_paths('diff', '--name-only', '-z', 'HEAD', '--') +
            git_paths('ls-files', '--others', '--exclude-standard', '-z')).intersection(entries).each do |path|
            @blockers << "#{path}: overlapping checkout edit; save or repair it before upgrading"
          end
        end

        def git_paths(*)
          output, error, status = Open3.capture3('git', '-C', @root, *)
          raise Error, "Cannot inspect checkout edits: #{error.strip}" unless status.success?

          output.split("\0")
        end
      end
    end
  end
end
