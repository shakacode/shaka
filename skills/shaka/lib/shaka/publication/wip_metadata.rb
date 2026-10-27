# frozen_string_literal: true

require 'json'
require_relative '../error'
require_relative 'wip_session'

module Shaka
  # Publishes only the disposition of each WIP field. A later handoff reads that record and does
  # not need the calling session. Withheld, invalid, and machine-name values stay out of it.
  class WipMetadata
    FIELDS = WipSession::FIELDS
    DISPOSITIONS = %w[available unavailable withheld invalid].freeze
    PREFIX = '<!-- shaka:wip-metadata '
    MARK = /#{Regexp.escape(PREFIX)}(.*?) -->/
    LABELS = { 'alias' => 'machine alias', 'host' => 'host', 'tag' => 'owner tag', 'thread' => 'chat link' }.freeze
    MISSING = 'WIP metadata collection evidence is missing; publish the description from the calling session.'
    UNREADABLE = 'WIP metadata collection evidence is unreadable; publish the description again.'

    def self.record(owner, thread, **session)
      dispositions = WipSession.new(owner, thread, session).dispositions
      "#{line(dispositions)}\n\n#{marker(dispositions)}"
    end

    def self.handoff_problem(note, owner:, thread:)
      packet = packet_from(note)
      return MISSING if packet.nil?
      return UNREADABLE unless valid?(packet)

      problems = FIELDS.filter_map { |field| problem(field, component(owner, thread, field), packet.fetch(field)) }
      problems.join(' ') unless problems.empty?
    end

    def self.marker(dispositions) = "#{PREFIX}#{JSON.generate(dispositions)} -->"

    def self.line(dispositions)
      "Collection: #{FIELDS.map { |field| "#{field} #{dispositions.fetch(field)}" }.join('; ')}."
    end

    def self.packet_from(note)
      text = note.to_s
      return if text.scan(PREFIX).empty?
      return :broken unless text.scan(PREFIX).one?

      JSON.parse(text[MARK, 1])
    rescue JSON::ParserError
      :broken
    end

    def self.valid?(packet)
      packet.is_a?(Hash) && packet.keys.sort == FIELDS &&
        packet.each_value.all? { |value| DISPOSITIONS.include?(value) }
    end

    def self.component(owner, thread, field)
      return thread if field == 'thread'

      parts = owner == 'UNKNOWN' ? %w[UNKNOWN UNKNOWN UNKNOWN] : owner.to_s.split('·', -1).map(&:strip)
      parts[FIELDS.index(field)]
    end

    def self.problem(field, value, disposition)
      return WipSession.share_message if field == 'thread' && WipSession.share_link?(value)
      return nil unless contradicted?(value, disposition)

      "#{LABELS.fetch(field)} #{contradiction(value, disposition)}."
    end

    def self.contradicted?(value, disposition)
      (value == 'UNKNOWN' && disposition == 'available') ||
        (value != 'UNKNOWN' && %w[withheld invalid].include?(disposition))
    end

    def self.contradiction(value, disposition)
      return 'was available but is UNKNOWN' if value == 'UNKNOWN'

      "was #{disposition} but a value was published"
    end

    private_class_method :packet_from, :valid?, :component, :problem, :contradicted?, :contradiction
  end
end
