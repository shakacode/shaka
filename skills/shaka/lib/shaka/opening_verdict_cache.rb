# frozen_string_literal: true

# Stores successful opening verdicts by hash without retaining description text.

require 'digest'
require 'fileutils'

module Shaka
  # Reuses only successful verdicts for the same opening, model, and prompt, which holds any description prose.
  class OpeningVerdictCache
    def initialize(opening:, model:, prompt:, directory:)
      key = Digest::SHA256.hexdigest([model, prompt, opening].join("\0"))
      @path = File.join(directory, key)
      @directory = directory
      @prompt = prompt
    end

    # The agent may keep a listed term, so a repeat of terms alone must not read as a fault to fix.
    FLAGGED = { 'flagged' => 'The unchanged text was previously flagged.',
                'flagged_terms' => 'An earlier check of this unchanged text listed terms and found no first-sentence ' \
                                   'problem. If you judged those terms and kept them, nothing more is needed.' }.freeze

    def read
      status = File.read(@path).strip
      return { 'status' => 'passed' } if status == 'passed'

      { 'status' => 'flagged', 'reason' => FLAGGED.fetch(status), 'prompt' => @prompt } if FLAGGED.key?(status)
    rescue SystemCallError, IOError
      nil
    end

    def write(verdict)
      return unless %w[passed flagged].include?(verdict['status'])

      FileUtils.mkdir_p(@directory, mode: 0o700)
      File.write(@path, verdict['terms_only'] ? 'flagged_terms' : verdict.fetch('status'), mode: 'w', perm: 0o600)
    rescue SystemCallError
      nil # A cache failure must not change the advisory result.
    end
  end
end
