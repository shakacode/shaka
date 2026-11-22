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
    TOKEN = /\A[A-Za-z0-9][A-Za-z0-9._:-]{0,79}\z/
    UNAVAILABLE = 'Antigravity current turn settings unavailable'

    def self.read(environment)
      file = AntigravityTranscript.session_file(environment)
      return { 'reason' => 'Antigravity transcript unavailable' } unless file

      new.read(file)
    end

    def read(file)
      clear(UNAVAILABLE)
      File.foreach(file, encoding: 'UTF-8') { |line| consume(AntigravityTranscript.parse(line)) }
      @settings.merge('reason' => @reason)
    rescue SystemCallError
      { 'reason' => 'Antigravity transcript unreadable' }
    end

    private

    # A user step starts a turn, which never inherits the settings of the one before it.
    def consume(record)
      return clear('Antigravity transcript contains unreadable metadata') unless record
      return clear(UNAVAILABLE) if record['type'] == 'USER_INPUT'

      response(AntigravityTranscript.model(record)) if AntigravityTranscript.response?(record)
    end

    def response(model)
      model = nil unless model&.match?(TOKEN) && model != 'UNKNOWN'
      @settings = { 'model' => model, 'effort' => AntigravityTranscript.effort(model) }
      @reason = model ? 'Antigravity model ID names no effort' : UNAVAILABLE
    end

    def clear(reason)
      @settings = {}
      @reason = reason
    end
  end
end
