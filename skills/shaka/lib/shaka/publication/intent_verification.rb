# frozen_string_literal: true

require_relative '../error'
require_relative 'text'
require_relative 'verification_gates'
require_relative 'diff_buckets'
require_relative 'human_review'
require_relative 'review_focus_list'

module Shaka
  # Renders what a pull request is for and how it was proved, so a maintainer can decide whether to trust it.
  module IntentVerification
    # Why and safety lead; scope closes the section with the diff it covers.
    INTENT = { 'why' => 'Why', 'safe_because' => 'Safe because' }.freeze
    # A bug fix names its cause apart from the symptom; other changes have none to name.
    ROOT_CAUSE = 'root_cause'
    CHECKS = (1..3)
    # A link opens the evidence and a code span names what ran; plain prose names neither.
    # GitHub also renders a link whose address sits in angle brackets.
    EVIDENCE = %r{\]\(https?://[^)\s]+\)|\]\(<https?://[^>\s]+>\)|`[^`]+`}

    module_function

    # The verdict binds the validation and review results; nil when description received none.
    # The floor comes from the PR's changed paths; without a pull request there is none.
    # The shortfall compares the bound reviews with the trusted reviewer count; nil when none.
    def render(content, verdict = nil, floor = nil, pull = nil, task: nil, shortfall: nil) # rubocop:disable Metrics/ParameterLists
      gate_line = VerificationGates.render(verdict, content['review'], shortfall)
      spec = object(content, 'verification')
      evidence(spec, content['wip'].nil? ? CHECKS : (0..CHECKS.max))
      [intent(object(content, 'intent'), floor, pull, task),
       verification(spec, gate_line)]
    end

    # The task follows Why, so a reader sees the problem and then where the work came from.
    def intent(spec, floor, pull, task = nil)
      lines = INTENT.map do |field, label|
        "**#{label}:** #{PublicationText.single_line(spec[field], "intent #{field}")}"
      end
      lines.insert(1, *task, *root_cause(spec))
      lines << HumanReview.render(spec['review_effort'], floor, pull)
      lines.concat(ReviewFocusList.render(spec, pull), exclusions(spec['leaves_out']))
      "## Intent\n\n#{[*lines, *scope(spec, pull)].join("\n\n")}"
    end

    def root_cause(spec)
      return [] if spec[ROOT_CAUSE].nil?

      ["**Root cause:** #{PublicationText.single_line(spec[ROOT_CAUSE], "intent #{ROOT_CAUSE}")}"]
    end

    def scope(spec, pull)
      ["**Scope:** #{PublicationText.single_line(spec['scope'], 'intent scope')}#{diff_size(pull)}",
       *(DiffBuckets.render(pull) if pull)]
    end

    def exclusions(value)
      return [] if value.nil? || value == '' || (value.is_a?(String) && value.strip.empty?)

      ["**Leaves out:** #{PublicationText.single_line(value, 'intent leaves_out')}"]
    end

    # GitHub supplies these counts for the published head; an author does not estimate them.
    def diff_size(pull)
      counts = pull&.values_at('changed_files', 'additions', 'deletions')
      return '' unless counts&.all? { |count| count.is_a?(Integer) && count >= 0 }

      files, added, removed = counts
      " (#{files} #{files == 1 ? 'file' : 'files'}, +#{added} / −#{removed} lines)"
    end

    def verification(spec, gate_line)
      visible = spec['merge_limitations']
      summary = evidenced(PublicationText.single_line(spec['summary'], 'verification summary')) if spec['summary']
      ['## Verification', gate_line, summary, *(not_verified(visible) unless visible.nil?)].compact.join("\n\n")
    end

    def evidence(spec, allowed)
      [*checks(spec['checks'], allowed), *not_verified(spec['not_verified'])].join("\n\n")
    end

    # The agent still answers, but a reader learns nothing from being told no claim went unproven.
    PROVED = /\Anothing\.?\z/i

    def not_verified(value)
      text = PublicationText.single_line(value, 'verification not_verified')
      text.match?(PROVED) ? [] : ["**Not verified:** #{text}"]
    end

    # An unfinished draft may have run nothing yet; Not verified then says why.
    def checks(value, allowed)
      listed = PublicationText.list(value, 'verification checks')
      unless allowed.cover?(listed.size)
        raise Error, "Publication verification checks must list #{allowed.min} to #{allowed.max} checks."
      end
      return [] if listed.empty?

      [listed.map { |check| "- #{evidenced(PublicationText.single_line(check, 'verification check'))}" }.join("\n")]
    end

    def evidenced(check)
      return check if check.match?(EVIDENCE)

      raise Error, "Publication verification check needs a Markdown link or a code span: #{check}"
    end

    def object(content, key)
      spec = content[key]
      raise Error, "Publication description requires #{key}." unless spec.is_a?(Hash)

      spec
    end

    private_class_method :intent, :scope, :exclusions, :diff_size,
                         :verification,
                         :not_verified, :checks, :evidenced, :object
  end
end
