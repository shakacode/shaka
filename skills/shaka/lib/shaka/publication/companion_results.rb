# frozen_string_literal: true

require 'uri'
require_relative 'text'

module Shaka
  # A companion run joins the attributed skill across phases and compares its reported commit to the live head.
  class CompanionResults
    SUMMARY = 'Companion skill results'
    REQUIRED = %w[skill command checked result not_covered commit artifacts].freeze
    DISCRIMINATORS = %w[source revision].freeze
    SHA = /\A\h{40}\z/
    HTTP_LINK = %r{https?://[^\s<>`"']+}i
    # Recognize workstation roots and paths attached to flags such as -I or -L.
    LOCAL_PATH = %r{
      (?<![\w./-])(?:--?[a-zA-Z][\w-]*)?(?:file:(?://(?:localhost)?)?)?(?:
        /(?:Users|home|private|tmp|var|Volumes|mnt|opt|root|workspaces?|etc|usr|run|srv|s?bin)/
        |[a-zA-Z]:[\\/]
      )
    }x

    def self.for(content, pull)
      detail = new(content['companion_results'], content['skills_used'], head: pull&.dig('head', 'sha')).detail
      detail ? [detail] : []
    end

    def initialize(entries, skills, head:)
      @entries = PublicationText.list(entries, 'companion_results')
      @skills = skills
      @head = head
    end

    def detail
      return if @entries.empty?

      { 'summary' => SUMMARY, 'body' => @entries.map { |entry| render(entry) }.join("\n\n") }
    end

    private

    def render(entry)
      validate_fields(entry)
      name = line(entry, 'skill')
      identity = skill_identity(entry)
      lines = ["**Source:** #{line(identity, 'source')}", "**Revision:** #{line(identity, 'revision')}",
               "**Command:** `#{command(entry['command'])}`",
               "**What it checked:** #{line(entry, 'checked')}", "**Result:** #{line(entry, 'result')}",
               "**Not covered:** #{line(entry, 'not_covered')}", commit_line(entry), artifact_line(entry['artifacts'])]
      "**#{name}**\n\n#{lines.compact.map { |item| "- #{item}" }.join("\n")}"
    end

    def validate_fields(entry)
      return if entry.is_a?(Hash) && (REQUIRED - entry.keys).empty? &&
                (entry.keys - REQUIRED - DISCRIMINATORS).empty?

      raise Error, 'Publication companion_results run fields do not match the allowlist.'
    end

    def skill_identity(entry)
      criteria = entry.slice(*DISCRIMINATORS)
      criteria.each_key { |field| line(entry, field) }
      identities = matching_identities(entry['skill'], criteria)
      raise Error, 'Publication companion_results skill matches no skills_used record.' if identities.empty?
      raise Error, 'Publication companion_results skill is ambiguous; supply source or revision.' unless identities.one?

      identities.first
    end

    def matching_identities(name, criteria)
      PublicationText.list(@skills, 'skills_used').grep(Hash).filter_map do |skill|
        skill.slice(*DISCRIMINATORS) if skill['name'] == name && skill.slice(*criteria.keys) == criteria
      end.uniq
    end

    def line(entry, field)
      value = entry[field]
      refuse_path(value, field)
      PublicationText.summary_text(value, "companion_results #{field}")
    end

    def command(value)
      unless value.is_a?(String) && !value.strip.empty? && !value.match?(%r{[`\r\n]|</})
        raise Error, 'Publication companion_results command must be one nonempty line without backticks or </.'
      end

      refuse_path(value, 'command')
      value
    end

    def commit_line(entry)
      sha = line(entry, 'commit')
      raise Error, 'Publication companion_results commit must be a full SHA.' unless SHA.match?(sha)

      label = if !SHA.match?(@head.to_s)
                ' · head unknown'
              elsif !sha.casecmp?(@head)
                ' · stale'
              end
      "**Commit:** `#{sha}`#{label}"
    end

    def artifact_line(value)
      unless value.is_a?(Array) && value.all? { |link| http_url?(link) }
        raise Error, 'Publication companion_results artifacts must be a list of HTTP or HTTPS URLs.'
      end
      return if value.empty?

      value.each { |link| refuse_path(link, 'artifacts') }
      "**Artifacts:** #{value.map { |link| "<#{link}>" }.join(' · ')}"
    end

    def http_url?(value)
      return false unless value.is_a?(String) && !value.match?(/[[:space:]<>]/)

      uri = URI.parse(value)
      uri.is_a?(URI::HTTP) && uri.host && !uri.host.empty?
    rescue URI::InvalidURIError
      false
    end

    def refuse_path(value, field)
      return unless value.is_a?(String)

      # An HTTP path names a remote resource. Its parameters can still embed local paths.
      text = value.gsub(HTTP_LINK) { |link| URI::DEFAULT_PARSER.unescape(link[/[?#].*/].to_s).scrub }
      return unless LOCAL_PATH.match?(text)

      raise Error, "Publication companion_results #{field} contains a local absolute path."
    end
  end
end
