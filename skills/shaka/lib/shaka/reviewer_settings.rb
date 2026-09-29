# frozen_string_literal: true

module Shaka
  # Names Shaka already prices or has seen a reviewer CLI accept.
  # `recommended_model` is the name Shaka tells a repository to set. Update it here when that
  # recommendation changes; doctor and review then tell repositories that still name the old one.
  module ReviewerCatalog
    Entry = Data.define(:recommended_model, :models, :efforts, :closed_effort)

    ENTRIES = {
      'openai/codex' => Entry.new(
        recommended_model: 'gpt-6-sol',
        models: %w[gpt-5.6-terra gpt-5.6-sol gpt-6-astra gpt-6-sol gpt-6-luna],
        efforts: %w[low medium high xhigh],
        closed_effort: false
      ),
      'anthropic/claude' => Entry.new(
        recommended_model: nil,
        models: %w[claude-fable-5-1 claude-fable-5 claude-opus-5-5 claude-opus-5 claude-opus-4-8
                   claude-opus-4-7 claude-opus-4-6 claude-opus-4-5 claude-sonnet-5 claude-sonnet-4-6
                   claude-sonnet-4-5 claude-haiku-4-5],
        efforts: %w[low medium high xhigh max],
        closed_effort: true
      ),
      'xai/grok' => Entry.new(
        recommended_model: nil,
        models: %w[grok-4.5 grok-4.6 grok-4.7],
        efforts: %w[low medium high],
        closed_effort: false
      )
    }.freeze

    def self.entry(identity) = ENTRIES[identity]
  end

  # Compares one configured reviewer model and effort with the catalog.
  class ReviewerSettings
    def self.refuse!(notices)
      blocking = notices.select { |notice| notice.fetch('severity') == 'failed' }
      return if blocking.empty?

      raise Error, blocking.map { |notice| notice.fetch('summary') }.join(' ')
    end

    def self.attach(result, model:, notices:)
      result = result.merge('requested_model' => model) if model
      notices&.any? ? result.merge('config_notices' => notices) : result
    end

    def self.notices(identity, model: nil, effort: nil)
      entry = ReviewerCatalog.entry(identity)
      return [] unless entry

      new(identity, entry, model, effort).notices
    end

    def initialize(identity, entry, model, effort)
      @identity = identity
      @entry = entry
      @model = present(model)
      @effort = present(effort)
    end

    def notices
      [model_notice, model_notice_for_known, effort_notice].compact
    end

    private

    def present(value)
      text = value.to_s
      return if text.strip.empty? || text == 'UNKNOWN'

      text
    end

    def model_notice
      return if @model.nil? || @model == @entry.recommended_model || @entry.models.include?(@model)

      suggestion = near_miss(@model, @entry.models)
      return typo('model', @model, suggestion) if suggestion

      summary = "#{@identity} model `#{@model}` is not a model Shaka knows."
      summary = "#{summary} Shaka recommends `#{@entry.recommended_model}`." if @entry.recommended_model
      notice('degraded', summary, 'Confirm the spelling. The review still runs with this model.')
    end

    def effort_notice
      return if @effort.nil? || @entry.efforts.include?(@effort)

      suggestion = near_miss(@effort, @entry.efforts)
      return typo('effort', @effort, suggestion) if suggestion
      return closed_effort if @entry.closed_effort

      notice('degraded', "#{@identity} effort `#{@effort}` is not a level Shaka knows.",
             'Confirm the spelling. The reviewer CLI decides whether it accepts this level.')
    end

    # A known model that is not the recommendation. Checked after membership, so a typo never lands here.
    def model_notice_for_known
      return if @model.nil? || @entry.recommended_model.nil? || @model == @entry.recommended_model
      return unless @entry.models.include?(@model)

      notice('degraded',
             "#{@identity} is set to `#{@model}`. Shaka recommends `#{@entry.recommended_model}` for that reviewer.",
             'Keep this model, or change the entry to the recommended one.')
    end

    def typo(kind, value, suggestion)
      notice('failed', "#{@identity} #{kind} `#{value}` looks like a typo of `#{suggestion}`.",
             'Correct review.local_review_agents before the review runs.')
    end

    def closed_effort
      listed = @entry.efforts.join(', ')
      notice('failed', "#{@identity} effort `#{@effort}` is not one of #{listed}.",
             'Use one of those levels. Claude rejects anything else.')
    end

    def near_miss(value, names)
      names.find { |name| one_edit?(value, name) }
    end

    def one_edit?(left, right)
      return false unless left.length == right.length

      indexes = left.chars.each_index.reject { |index| left[index] == right[index] }
      indexes.length == 1 || transposed?(left, right, indexes)
    end

    def transposed?(left, right, indexes)
      return false unless indexes.length == 2 && indexes[1] == indexes[0] + 1

      left[indexes[0]] == right[indexes[1]] && left[indexes[1]] == right[indexes[0]]
    end

    def notice(severity, summary, guidance)
      { 'severity' => severity, 'summary' => summary, 'guidance' => guidance }
    end
  end
end
