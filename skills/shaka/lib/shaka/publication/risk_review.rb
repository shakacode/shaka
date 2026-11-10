# frozen_string_literal: true

require_relative '../error'
require_relative '../post_implementation/risk'
require_relative 'text'
require_relative 'review_focus_list'

module Shaka
  # Renders how carefully to review a PR and where to start: the checkpoint's risk level and what it asks of the
  # reader, the code the implementer flagged, the reviewer's reasons, and a repository's own risk record. The
  # pull's shaka_risk is the assessment the description command read from this head's checkpoint, as merge
  # reads it; only a description is rendered with a pull.
  module RiskReview
    HEADING = '## Risk and review'
    CHECKPOINT_URL = %r{\Ahttps://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/pull/\d+#issuecomment-\d+\z}
    # A record body folds inside details, so it must not open or close one.
    FOLD_TAG = %r{</?(?:details|summary)\b}i

    module_function

    # The lead-line level, or nil when the description carries no checkpoint.
    def lead(content, pull)
      return unless content['checkpoint'].is_a?(Hash)

      level = assessment(pull)&.fetch('level')
      return "**Risk: #{level.capitalize}**" if level

      withheld?(pull) ? '**Risk: not shown**' : '**Risk: not rated yet**'
    end

    # Intent's own renderer refuses a missing intent, after this section.
    def render(content, pull)
      intent = content['intent']
      focus = ReviewFocusList.render(intent.is_a?(Hash) ? intent : {}, pull)
      record = record(content['risk_record'])
      rated = assessment(pull)
      return [] unless rated || focus.any? || record.any?

      opening = rated ? level_line(rated) : unrated(content, pull)
      ["#{HEADING}\n\n#{[opening, *focus, *(rated ? notes(rated) : []), *record].join("\n\n")}"]
    end

    def unrated(content, pull)
      if withheld?(pull)
        return "**Not shown.** Shaka could not read this repository's trusted settings, so it cannot check " \
               'the high-risk areas merge checks. The checkpoint states its own rating.'
      end
      return '**Not rated yet.** No published checkpoint rates this commit.' if content['checkpoint'].is_a?(Hash)

      '**Not rated.** No checkpoint rated this commit.'
    end

    def withheld?(pull) = pull&.dig('shaka_risk', 'withheld').is_a?(String)

    def assessment(pull)
      risk = pull&.dig('shaka_risk')
      risk if risk.is_a?(Hash) && PostImplementationRisk::LEVELS.include?(risk['level'])
    end

    # Reuses the checkpoint's own sentences. A plain rating bolds the level where the action names it; a raised
    # one keeps the area that raised it beside the bold level.
    def level_line(rated)
      level = rated['level'].capitalize
      heading = PostImplementationRisk.heading(rated)
      action = PostImplementationRisk.action(rated)
      prefix = "#{level} risk"
      return "**#{prefix}**#{action.delete_prefix(prefix)}" if heading == "#{level}." && action.start_with?(prefix)

      "**#{level}**#{heading.delete_prefix(level)} #{action}"
    end

    def notes(rated)
      unread = rated['paths_read'] == false ? [PostImplementationRisk::UNREAD_FILES] : []
      [*unread, *reasons(rated)]
    end

    # The reasons are the checkpoint reviewer's, labeled as theirs; when an area raised the level, the label says
    # what the reviewer rated instead. A low rating keeps them folded. Otherwise they are quoted, which marks them
    # as another author's words and keeps them out of the prose limits, since the description's author cannot
    # shorten them.
    def reasons(rated)
      reasons = Array(rated['reasons'])
      return [] if reasons.empty?

      list = reasons.map { |reason| "- #{PublicationText.single_line(reason, 'checkpoint risk reason')}" }.join("\n")
      level = rated['level']
      return ["<details>\n<summary>Why low, from the checkpoint</summary>\n\n#{list}\n\n</details>"] if level == 'low'

      ["#{reasons_label(rated, checkpoint(rated['url']))}\n\n#{list.gsub(/^/, '> ')}"]
    end

    def reasons_label(rated, checkpoint)
      rating = rated['rating']
      return "**Why #{rated['level']}**, from the #{checkpoint}:" if rating == rated['level']
      return "**The #{checkpoint} reviewer could not rate it:**" if rating == 'unknown'

      "**The #{checkpoint} reviewer rated it #{rating}:**"
    end

    def checkpoint(url) = url.is_a?(String) && url.match?(CHECKPOINT_URL) ? "[checkpoint](#{url})" : 'checkpoint'

    # A repository's own risk record, such as one its project guidance asks for, folds at the end.
    def record(spec)
      return [] if spec.nil?
      raise Error, 'Publication risk_record must be an object with summary and body.' unless spec.is_a?(Hash)

      unknown = spec.keys - %w[summary body]
      raise Error, "Publication risk_record has unknown fields: #{unknown.join(', ')}." if unknown.any?

      summary = PublicationText.summary_text(spec['summary'], 'risk_record summary')
      body = PublicationText.required(spec['body'], 'risk_record body')
      raise Error, 'Publication risk_record body must not contain details or summary tags.' if body.match?(FOLD_TAG)

      ["<details>\n<summary>#{summary}</summary>\n\n#{body}\n\n</details>"]
    end

    private_class_method :assessment, :unrated, :withheld?, :level_line, :notes, :reasons, :reasons_label,
                         :checkpoint, :record
  end
end
