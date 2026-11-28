# frozen_string_literal: true

require 'digest'
require 'json'
require_relative 'shell'

module ShakaRelease
  # The approval file that `prepare` wrote and a person approved, with its files checked on each use.
  class Approval
    include Shell

    REQUIRED = %w[commit version gem gem_sha256 notes notes_sha256 behavior_gate].freeze
    SKIPPED_GATE = 'The release behavior gate did not run for this release.'

    def initialize(path)
      @values = JSON.parse(File.read(path))
      refuse 'approval file must hold a JSON object' unless @values.is_a?(Hash)
      missing = REQUIRED.reject { |key| @values[key] }
      refuse "approval file lacks #{missing.join(', ')}" unless missing.empty?
      check_shape
    end

    def commit = @values.fetch('commit')
    def version = @values.fetch('version')
    def gem_sha256 = @values.fetch('gem_sha256')
    def prerelease? = Gem::Version.new(version).prerelease?

    # The gem path, after its bytes are checked against the approved digest.
    def gem = checked('gem')

    # The approved notes, plus a statement when the behavior gate did not run.
    def release_body
      notes = File.read(checked('notes'))
      gate_skipped? ? "#{notes.chomp}\n\n#{SKIPPED_GATE}\n" : notes
    end

    def gate_skipped? = @values.dig('behavior_gate', 'status') == 'skipped'

    def check_files = %w[gem notes].each { checked(it) }

    private

    # Checked before any publication step, so a malformed file cannot stop publish halfway.
    def check_shape
      refuse 'approval file was not ready for approval' unless @values['status'] == 'ready_for_approval'
      refuse 'approval file has an invalid version' unless Gem::Version.correct?(@values['version'].to_s)
      refuse 'approval file has an invalid commit' unless @values['commit'].to_s.match?(/\A\h{40}\z/)
      gate = @values['behavior_gate']
      refuse 'approval file has an invalid behavior gate' unless
        gate.is_a?(Hash) && %w[passed skipped].include?(gate['status'])
    end

    def checked(name)
      path = @values.fetch(name)
      refuse "#{name} file differs from the approval" unless
        Digest::SHA256.file(path).hexdigest == @values.fetch("#{name}_sha256")
      path
    rescue SystemCallError => e
      refuse "#{name} file: #{e.message}"
    end
  end
end
