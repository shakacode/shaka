# frozen_string_literal: true

require 'digest'
require 'fileutils'

module Shaka
  # Keeps successful opening verdicts on this host without storing description text.
  class OpeningVerdictCache
    def initialize(opening:, model:, prompt:, directory: nil)
      directory ||= File.join(Dir.home, '.cache', 'shaka', 'opening-check')
      key = Digest::SHA256.hexdigest([model, prompt, opening].join("\0"))
      @path = File.join(directory, key)
      @directory = directory
    end

    def read
      status = File.read(@path).strip
      return { 'status' => 'passed' } if status == 'passed'
      return { 'status' => 'flagged', 'reason' => 'The unchanged opening was previously flagged.' } if
        status == 'flagged'

      nil
    rescue SystemCallError, IOError
      nil
    end

    def write(verdict)
      return unless %w[passed flagged].include?(verdict['status'])

      FileUtils.mkdir_p(@directory, mode: 0o700)
      File.write(@path, verdict.fetch('status'), mode: 'w', perm: 0o600)
    rescue SystemCallError
      nil # A cache failure must not change the advisory result.
    end
  end
end
