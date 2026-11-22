# frozen_string_literal: true

require_relative 'antigravity_usage'

module Shaka
  # Reads only the current publisher's model ID from its transcript, never transcript prose.
  class AntigravityPublisherSettings
    AGENT = 'Antigravity'
    # The transcript records the model the user selected, not the one the service ran.
    MODEL_SUFFIX = ' (configured)'
    NOTE = nil
    # The transcript does not record which service served the model, so the provider stays as supplied.
    FIELDS = %w[model effort].freeze
    UNAVAILABLE = 'Antigravity current turn settings unavailable'

    def self.read(environment)
      file = AntigravityTranscript.session_file(environment)
      return { 'reason' => 'Antigravity transcript unavailable' } unless file

      new.read(file)
    end

    def read(file)
      steps, skipped = AntigravityTranscript.steps(file)
      # A line that cannot be read could be the step that started the current turn.
      return { 'reason' => 'Antigravity transcript contains unreadable metadata' } if skipped.positive?

      clear('Antigravity transcript has no user turn')
      steps.each { |step| consume(step) }
      @settings.merge('reason' => @reason)
    rescue SystemCallError
      { 'reason' => 'Antigravity transcript unreadable' }
    end

    private

    # A user step starts a turn, which never inherits the settings of the one before it.
    # A response before the first user step belongs to no turn.
    def consume(step)
      if AntigravityTranscript.user_input?(step)
        @turn = true
        clear(UNAVAILABLE)
      elsif @turn && AntigravityTranscript.response?(step)
        response(AntigravityTranscript.model(step))
      end
    end

    def response(model)
      @settings = { 'model' => model, 'effort' => AntigravityTranscript.effort(model) }
      @reason = model ? 'Antigravity model ID names no effort' : UNAVAILABLE
    end

    def clear(reason)
      @settings = {}
      @reason = reason
    end
  end
end
