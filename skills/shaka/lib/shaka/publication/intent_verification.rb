# frozen_string_literal: true

require_relative '../error'
require_relative 'text'

module Shaka
  # Renders what a pull request is for and how it was proved, so a maintainer can decide whether to trust it.
  module IntentVerification
    INTENT = { 'why' => 'Why', 'scope' => 'Scope', 'leaves_out' => 'Leaves out',
               'safe_because' => 'Safe because' }.freeze
    CHECKS = (1..3)
    # A reader can open a link or rerun a command; a bare claim of success gives them neither.
    EVIDENCE = %r{\]\(https?://[^)\s]+\)|`[^`]+`}

    module_function

    def render(content) = [intent(object(content, 'intent')), verification(object(content, 'verification'))]

    def intent(spec)
      lines = INTENT.map do |field, label|
        "**#{label}:** #{PublicationText.single_line(spec[field], "intent #{field}")}"
      end
      "## Intent\n\n#{lines.join("\n\n")}"
    end

    def verification(spec)
      not_verified = PublicationText.single_line(spec['not_verified'], 'verification not_verified')
      "## Verification\n\n#{checks(spec['checks']).join("\n")}\n\n**Not verified:** #{not_verified}"
    end

    def checks(value)
      listed = PublicationText.list(value, 'verification checks')
      raise Error, 'Publication verification checks must list 1 to 3 checks.' unless CHECKS.cover?(listed.size)

      listed.map { |check| "- #{evidenced(PublicationText.single_line(check, 'verification check'))}" }
    end

    def evidenced(check)
      return check if check.match?(EVIDENCE)

      raise Error, "Publication verification check needs a link or a command a reader can rerun: #{check}"
    end

    def object(content, key)
      spec = content[key]
      raise Error, "Publication description requires #{key}." unless spec.is_a?(Hash)

      spec
    end

    private_class_method :intent, :verification, :checks, :evidenced, :object
  end
end
