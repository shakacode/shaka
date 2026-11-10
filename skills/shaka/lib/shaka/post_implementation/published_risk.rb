# frozen_string_literal: true

require_relative '../error'
require_relative '../publication/text'
require_relative '../pull_changed_files'
require_relative 'risk'

module Shaka
  # Reads back what a published checkpoint printed about risk, so the description shows the same rating with the
  # assessment merge would make from it.
  module PostImplementationPublishedRisk
    # PostImplementationRisk.section's reasons: the bullets between its Risk line and its footnote.
    REASONS = /^\*\*Risk:\*\* [^\n]*\n((?:- [^\n]*\n)+)\n_With `merge\.auto_merge_max_risk: /
    # Markup that could end a description's folded block or plant a marker in it.
    UNSAFE = %r{<!--|</?(?:details|summary)\b}i
    # A rated head whose trusted settings could not be read: the packaged areas could rate it lower than the
    # repository's own, so the description withholds the level.
    WITHHELD = { 'withheld' => 'trusted settings unread' }.freeze

    module_function

    # This head's published rating as the description shows it: the assessment merge would make from it, the
    # reviewer's reasons, and the checkpoint's link; nil when no checkpoint for the head published a rating, and
    # WITHHELD when seam, the trusted settings, is nil. evidence answers published_risk(head) with this account's
    # latest checkpoint. As in merge, a head or base that moves while the files are read stops the description
    # instead of rating the files unread.
    def assessment(seam, github, head, evidence)
      found = evidence.published_risk(head)
      return unless found
      return WITHHELD unless seam

      high, medium = PostImplementationRisk.areas(seam)
      PostImplementationRisk.assess(found.fetch('rating'), high, paths(github, head), medium)
                            .merge('max_risk' => PostImplementationRisk.max_risk(seam), **found.slice('reasons', 'url'))
    end

    def paths(github, head)
      PullChangedFiles.new.paths(github, head)
    rescue PullChangedFiles::Moved
      raise
    rescue Error, SystemCallError
      nil
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

    private_class_method :paths, :publishable?
  end
end
