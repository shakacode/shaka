# frozen_string_literal: true

# Validates model-produced opening parses before code applies the verdict rule.

require 'json'

module Shaka
  # Checks the model answer's JSON shape before the verdict rule reads it.
  module OpeningParse
    MAX_REPORT_BYTES = 20_000
    FIELDS = %w[character reader_facing character_can_act action object hidden_actions internal_terms].freeze
    TERM_FIELDS = %w[term where plain_wording].freeze

    private

    def parse_report(path)
      raise Shaka::Error, 'the model parse is too large' if File.size(path) > MAX_REPORT_BYTES

      text = File.read(path, encoding: 'UTF-8').strip
      text = text.sub(/\A```(?:json)?\s*\n/, '').delete_suffix("\n```")
      JSON.parse(text)
    end

    def judge(result)
      sentences = result.is_a?(Hash) && result['sentences']
      sentences = sentences.first(self.class::SENTENCE_LIMIT) if sentences.is_a?(Array)
      terms = unclear_terms(result)
      return not_checked('the model returned no usable parse') unless valid_sentences?(sentences) && terms

      self.class.verdict(sentences, terms)
    end

    # Only description prose asks for terms, so an opening alone has none to read.
    def unclear_terms(result)
      return [] unless @prose

      terms = result.is_a?(Hash) && result['unclear_terms']
      terms.first(self.class::TERM_LIMIT) if terms.is_a?(Array) && terms.all? { |entry| valid_term?(entry) }
    end

    def valid_term?(entry) = entry.is_a?(Hash) && TERM_FIELDS.all? { |key| entry[key].is_a?(String) }

    def valid_sentences?(sentences)
      sentences.is_a?(Array) && !sentences.empty? && sentences.all? do |sentence|
        valid_sentence?(sentence)
      end
    end

    def valid_sentence?(sentence)
      return false unless sentence.is_a?(Hash) && (FIELDS - sentence.keys).empty?
      return false unless %w[reader_facing character_can_act].all? { |key| sentence[key] in true | false }

      text_fields?(sentence) && array_fields?(sentence)
    end

    def text_fields?(sentence) = %w[character action object].all? { |key| sentence[key].is_a?(String) }

    def array_fields?(sentence)
      %w[hidden_actions internal_terms].all? do |key|
        sentence[key].is_a?(Array) && sentence[key].all?(String)
      end
    end
  end
end
