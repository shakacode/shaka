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
      missing = REQUIRED.reject { |key| @values[key] }
      refuse "approval file lacks #{missing.join(', ')}" unless missing.empty?
      refuse 'approval file was not ready for approval' unless @values['status'] == 'ready_for_approval'
      refuse 'approval file has an invalid version' unless Gem::Version.correct?(@values['version'].to_s)
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
