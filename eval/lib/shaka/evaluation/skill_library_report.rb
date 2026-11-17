# frozen_string_literal: true

module Shaka
  module Evaluation
    # Turns the texts SkillLibraryTexts builds and the counts InstructionTokens.count_each returns into
    # one row per library: words per text and, when counted, each CLI's tokens or UNKNOWN.
    module SkillLibraryReport
      KINDS = %w[every_session median_skill largest_skill].freeze

      module_function

      # A key per distinct text. Identical texts, such as Shaka's one skill as both median and largest,
      # share the first key, so each is counted once.
      def keys(libraries)
        libraries.each_with_object({}) do |library, keys|
          KINDS.each { |kind| keys[text(library, kind)] ||= "#{library['library']} #{kind}" }
        end
      end

      def rows(libraries, keys, counts)
        libraries.map do |library|
          measured = KINDS.to_h { |kind| [kind, measured(library, kind, keys, counts)] }
          library.slice('library', 'commit', 'skills', 'commands').merge(measured)
        end
      end

      # A CLI whose own prompt could not be measured has no texts, so each of its counts is UNKNOWN.
      def measured(library, kind, keys, counts)
        row = { 'words' => text(library, kind).split.size }
        row['name'] = library[kind]['name'] unless kind == 'every_session'
        counts&.each { |cli| row[cli['cli']] = cli['texts'] ? cli['texts'][keys[text(library, kind)]] : 'UNKNOWN' }
        row
      end

      def text(library, kind) = kind == 'every_session' ? library[kind] : library[kind]['text']
    end
  end
end
