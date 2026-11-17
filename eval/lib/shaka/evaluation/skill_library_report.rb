# frozen_string_literal: true

module Shaka
  module Evaluation
    # Turns the texts SkillLibraryTexts builds and the counts InstructionTokens.count_each returns into
    # one row per library: words per text and, when counted, each CLI's tokens or UNKNOWN.
    module SkillLibraryReport
      KINDS = %w[every_session median_skill largest_skill].freeze

      # Claude runs with no tools. Codex keeps some tools however it runs, such as web search, image
      # viewing, and the account's connected apps, so only Shaka's own text goes to it.
      SENT = ->(cli, key) { cli == 'claude' || key.start_with?('shaka ') }

      module_function

      # A key per distinct text. Identical texts, such as Shaka's one skill as both median and largest,
      # share the first key, so each is counted once.
      def keys(libraries)
        libraries.each_with_object({}) do |library, keys|
          KINDS.each { |kind| keys[text(library, kind)] ||= "#{library['library']} #{kind}" }
        end
      end

      def count(keys, runner: nil)
        require_relative '../../../../lib/instruction_tokens'
        InstructionTokens.count_each(keys.invert, runner:, sent: SENT)
      end

      def rows(libraries, keys, counts)
        libraries.map do |library|
          measured = KINDS.to_h { |kind| [kind, measured(library, kind, keys, counts)] }
          library.slice('library', 'commit', 'skills', 'commands').merge(measured)
        end
      end

      def measured(library, kind, keys, counts)
        body = text(library, kind)
        row = { 'words' => body.split.size }
        row['name'] = library[kind]['name'] unless kind == 'every_session'
        row.merge(counted(keys[body], counts))
      end

      # Each CLI the text was sent to. One whose own prompt could not be measured has no texts, so
      # each text sent to it is UNKNOWN.
      def counted(key, counts)
        Array(counts).select { |cli| SENT.call(cli['cli'], key) }
                     .to_h { |cli| [cli['cli'], cli['texts'] ? cli['texts'][key] : 'UNKNOWN'] }
      end

      def text(library, kind) = kind == 'every_session' ? library[kind] : library[kind]['text']
    end
  end
end
