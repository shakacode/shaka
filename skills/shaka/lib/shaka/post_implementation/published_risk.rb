# frozen_string_literal: true

require_relative '../error'
require_relative '../publication/text'
require_relative 'risk'

module Shaka
  # Reads back what a published checkpoint printed about risk, so the description shows the same rating with the
  # assessment merge would make from it.
  module PostImplementationPublishedRisk
    # PostImplementationRisk.section's reasons: the bullets between its Risk line and its footnote.
    REASONS = /^\*\*Risk:\*\* [^\n]*\n((?:- [^\n]*\n)+)\n_With `merge\.auto_merge_max_risk: /
    # Markup that could end a description's folded block or plant a marker in it.
    UNSAFE = %r{<!--|</?(?:details|summary)\b}i

    module_function

    # This head's published rating as the description shows it: the assessment merge would make from it, the
    # reviewer's reasons, and the checkpoint's link; nil when no checkpoint for the head published a rating.
    # evidence answers published_risk(head) with this account's latest checkpoint.
    def assessment(seam, github, head, evidence)
      found = evidence.published_risk(head)
      return unless found

      PostImplementationRisk.from(seam, github, head, found.fetch('rating')).merge(found.slice('reasons', 'url'))
    end

    # The reviewer wrote the reasons after reading the diff, so they arrive as outside text: the line Ruby adds
    # is left out, and a reason with markup that could break the description, or one the description's text
    # checks would refuse, drops them all, leaving the checkpoint link.
    def reasons_in(body)
      reasons = body.gsub("\r\n", "\n").match(REASONS)&.[](1).to_s.lines
                    .map { |line| line.chomp.delete_prefix('- ') } - [PostImplementationRisk::UNREAD_FILES]
      reasons.all? { |reason| publishable?(reason) } ? reasons : []
    end

    def publishable?(reason)
      !reason.match?(UNSAFE) && PublicationText.single_line(reason, 'checkpoint risk reason')
    rescue Error
      false
    end

    private_class_method :publishable?
  end
end
