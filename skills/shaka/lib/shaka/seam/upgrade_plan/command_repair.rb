# frozen_string_literal: true

module Shaka
  class Seam
    class UpgradePlan
      # Content repairs for moved command entry points.
      module CommandRepair
        private

        def repaired_file(old, target, source)
          return source unless old.start_with?("#{PATHS::COMMAND_DIRECTORY}/")

          text = source.fetch('data').unpack1('m0').force_encoding(Encoding::UTF_8)
          repaired, kind = checked_repair(old, text)
          return unless repaired

          @repairs << { 'path' => target, 'kind' => kind } if kind
          source.merge('data' => [repaired.b].pack('m0'))
        end

        def checked_repair(old, text)
          return invalid_script(old, 'executable content is not UTF-8; inspect it manually') unless text.valid_encoding?

          repaired, kind = repair_root(text)
          return invalid_script(old, 'ambiguous repository-root calculation; repair it explicitly') unless repaired
          return invalid_script(old, 'invocation-relative dependency') if invocation_relative?(repaired)
          return invalid_script(old, 'old command path; repair it explicitly') if old_path?(repaired)

          [repaired, kind]
        end

        def invalid_script(path, message)
          @blockers << "#{path}: #{message} before upgrading"
          nil
        end

        def old_path?(text)
          matching_paths(text).any?
        end
      end
    end
  end
end
