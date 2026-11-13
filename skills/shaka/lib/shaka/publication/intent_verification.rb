# frozen_string_literal: true

require_relative '../error'
require_relative 'text'
require_relative 'verification_gates'
require_relative 'diff_buckets'

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
    # The shortfall compares the bound reviews with the trusted reviewer count; nil when none.
    # An intent review_effort, the retired 1-5 rating, is ignored.
    def render(content, verdict = nil, pull = nil, task: nil, shortfall: nil)
      gate_line = VerificationGates.render(verdict, content['review'], shortfall)
      spec = object(content, 'verification')
      evidence(spec, content['wip'].nil? ? CHECKS : (0..CHECKS.max))
      [intent(object(content, 'intent'), pull, task),
       verification(spec, gate_line)]
    end

    # The task follows Why, so a reader sees the problem and then where the work came from.
    def intent(spec, pull, task = nil)
      lines = INTENT.map do |field, label|
        "**#{label}:** #{PublicationText.single_line(spec[field], "intent #{field}")}"
      end
      lines.insert(1, *task_with_understanding(task, spec['task_understanding']), *root_cause(spec))
      lines.concat(exclusions(spec['leaves_out']))
      "## Intent\n\n#{[*lines, *scope(spec, pull)].join("\n\n")}"
    end

    UNDERSTANDING = { 'goal' => 'Goal', 'done_when' => 'Done when' }.freeze

    # The understanding nests under the Task line, so every paragraph reads as part of the task.
    def task_with_understanding(task, value)
      return [*task] if value.nil?

      ["#{task || '**Task as understood:**'}\n#{understanding_items(value).join("\n")}"]
    end

    # Callers supply the goal and its success criteria; text from older callers keeps its paragraphs.
    def understanding_items(value)
      return [legacy_understanding(value)] unless value.is_a?(Hash)

      extra = value.keys - UNDERSTANDING.keys
      raise Error, "Publication intent task_understanding has unknown keys: #{extra.join(', ')}." if extra.any?

      UNDERSTANDING.map do |field, label|
        "- **#{label}:** #{PublicationText.single_line(value[field], "intent task_understanding #{field}")}"
      end
    end

    def legacy_understanding(value)
      paragraphs = PublicationText.required(value, 'intent task_understanding').strip.split(/\n\s*\n/)
      "- **As understood:** #{paragraphs.map { |text| text.strip.gsub("\n", "\n  ") }.join("\n\n  ")}"
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

    # An unproven claim stays visible: a maintainer deciding whether to merge must not have to open the fold.
    def verification(spec, gate_line)
      summary = evidenced(PublicationText.single_line(spec['summary'], 'verification summary')) if spec['summary']
      ['## Verification', gate_line, summary, *not_verified(spec['not_verified']),
       *merge_limitations(spec['merge_limitations'])].compact.join("\n\n")
    end

    def evidence(spec, allowed) = checks(spec['checks'], allowed).join("\n\n")

    # The agent still answers, but a reader learns nothing from being told no claim went unproven.
    PROVED = /\Anothing\.?\z/i

    def proved?(text) = text.to_s.strip.match?(PROVED)

    def not_verified(value)
      text = PublicationText.single_line(value, 'verification not_verified')
      proved?(text) ? [] : ["**Not verified:** #{text}"]
    end

    def merge_limitations(value)
      return [] if value.nil? || proved?(value)

      ["**Merge limitations:** #{PublicationText.single_line(value, 'verification merge_limitations')}"]
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

    private_class_method :intent, :task_with_understanding, :understanding_items, :legacy_understanding,
                         :scope, :exclusions, :diff_size, :verification,
                         :not_verified, :merge_limitations, :checks, :evidenced, :object
  end
end
