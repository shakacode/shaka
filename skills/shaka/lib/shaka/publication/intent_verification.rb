# frozen_string_literal: true

require_relative '../error'
require_relative 'text'
require_relative 'verification_gates'
require_relative 'diff_buckets'
require_relative 'review_focus_list'

module Shaka
  # Renders what a pull request is for and how it was proved, so a maintainer can decide whether to trust it.
  module IntentVerification
    # Why and safety lead; scope closes the section with the diff it covers.
    INTENT = { 'why' => 'Why', 'safe_because' => 'Safe because' }.freeze
    # A bug fix names its cause apart from the symptom; other changes have none to name.
    ROOT_CAUSE = 'root_cause'
    # Like heart-rate zones: the blast radius sets how hard a reviewer should work.
    REVIEW_EFFORT = {
      1 => 'recovery: read the description.',
      2 => 'easy: skim the diff.',
      3 => 'tempo: read the walkthrough and the diff.',
      4 => 'threshold: read every line and run it yourself.',
      5 => 'all out: review every line, reproduce it, and ask a second reviewer.'
    }.freeze
    CHECKS = (1..3)
    SAFE_PATH = %r{\A[\w.@+/ -]+\z}
    # A link opens the evidence and a code span names what ran; plain prose names neither.
    # GitHub also renders a link whose address sits in angle brackets.
    EVIDENCE = %r{\]\(https?://[^)\s]+\)|\]\(<https?://[^>\s]+>\)|`[^`]+`}

    module_function

    # The verdict binds the validation and review results; nil when description received none.
    # The floor comes from the PR's changed paths; without a pull request there is none.
    # The shortfall compares the bound reviews with the trusted reviewer count; nil when none.
    def render(content, verdict = nil, floor = nil, pull = nil, task: nil, shortfall: nil) # rubocop:disable Metrics/ParameterLists
      gate_line = VerificationGates.render(verdict, content['review'], shortfall,
                                           VerificationGates.unlabeled(content, pull))
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
      lines << review_effort(spec['review_effort'], floor)
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

    def review_effort(effort, floor)
      zone = REVIEW_EFFORT[effort] if effort.is_a?(Integer)
      raise Error, 'Publication intent review_effort must be a whole number from 1 to 5.' unless zone

      line = "**Review effort:** #{effort} of 5, #{zone}"
      return line unless floor

      [line, *floor_text(effort, floor), *(SHIPPED if floor['shipped'])].join(' ')
    end

    # The repository's floors can be stricter, so a description that never read them says so.
    SHIPPED = "Shaka's shipped floors applied because this repository's settings were not read."

    def floor_text(effort, floor)
      return [] unless floor['level'] > 1

      reason = "#{floor['reason']} (#{floor_path(floor['path'])})"
      if effort < floor['level']
        raise Error, "Publication intent review_effort #{effort} is below this PR's floor of #{floor['level']}: " \
                     "it #{reason}. Rate it #{floor['level']} or higher."
      end

      ["Floor #{floor['level']}: #{reason}."]
    end

    # A changed filename comes from the PR author, so only a plain one reaches the description.
    def floor_path(path) = path.match?(SAFE_PATH) ? "`#{path}`" : 'a file whose name is withheld'

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
                         :review_effort, :floor_text, :floor_path, :verification,
                         :not_verified, :checks, :evidenced, :object
  end
end
