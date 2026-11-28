# frozen_string_literal: true

require_relative '../error'
require_relative '../handoff/wip_note'
require_relative '../publication/text'
require_relative 'owner_tag'
require_relative 'ownership'
require_relative 'release_report'

module Shaka
  class BranchHead
    # Posts the release and pickup comments that move an unfinished PR from one owner to the next. Each names the
    # deciding comment it was made against and is confirmed by reading the PR again, so a write that did not count
    # says so on the PR and in the result.
    class Handover
      RELEASED = 'Released. End this task, and report the release link and any local work left behind.'
      LOST = 'The pickup did not count: another came first, or this account cannot override. Leave the branch ' \
             'and PR alone and tell the user who owns it.'
      UNSEEN = 'GitHub does not list the comment yet, so whether it counted is unknown. Run `branch check --pr` ' \
               'before anything else.'

      def initialize(head, ownership, content, root)
        @head = head
        @root = root
        @ownership = ownership
        @content = content
        @tag = owner_tag
      end

      # Only the owner, from its own checkout, can say what is unpushed; a maintainer's release says what it knows.
      def release(pull, maintainer:)
        before = @ownership.state
        refuse_release(before, pull, maintainer)
        rows = ReleaseReport.new(@root, pull, @content).rows(maintainer, @tag)
        comment = post('Released this PR for pickup.', rows, mark(before, 'release', maintainer, pull['head']))
        after = settled(comment)
        uncounted_release(comment, after) unless took?(after, comment)
        { 'state' => 'released', 'release' => comment['html_url'], 'guidance' => RELEASED }
      end

      # The first pickup GitHub stores after the latest release wins. A loser's comment is edited to say so.
      def pickup(pull, override: false)
        before = @ownership.state
        return own(before['url']) if holds?(before) && OwnerTag.recorded(@root) == @tag

        refuse_pickup(before, pull, override)
        lead = override ? 'Took over this PR as a maintainer override.' : 'Picked up this PR.'
        outcome(post(lead, { 'New owner' => "`#{@tag}`" }, mark(before, 'pickup', override)))
      end

      private

      def uncounted_release(comment, after)
        void(comment, 'This release did not take effect.')
        raise Error, 'The release did not take effect: the PR changed hands first, or this account cannot release ' \
                     "it (#{after['url'] || 'no deciding comment'})."
      end

      def took?(after, comment) = after['applied'].include?(comment['id'])

      def holds?(state) = state['owner'] == @tag && !state['released']

      def outcome(comment)
        after = settled(comment)
        return own(comment['html_url']) if took?(after, comment) && holds?(after)
        return superseded(after) if took?(after, comment)

        void(comment, 'This pickup did not take effect.')
        { 'state' => 'lost', 'owner' => after['owner'], 'winner' => after['url'], 'guidance' => LOST }
      end

      # The pickup counted, but a maintainer override or release already followed it.
      def superseded(after)
        state = after['released'] ? 'released' : 'taken_over'
        { 'state' => state, 'owner' => after['owner'], 'decided_by' => after['url'],
          'guidance' => Ownership::GUIDANCE[state] }
      end

      def refuse_release(state, pull, maintainer)
        raise Error, 'The PR is already released; nothing to release.' if state['released']

        holder = state['owner'] || wip_tag(pull['body'])
        return if maintainer || holder.nil? || holder == @tag

        raise Error, "#{holder} owns this PR; only that owner or a maintainer (--maintainer) can release it."
      end

      # A pickup is refused before it posts unless the PR is released and this checkout's origin branch holds the
      # PR head.
      def refuse_pickup(state, pull, override)
        unless override || state['released']
          raise Error, 'The PR is not released. Ask its owner to release it, or pass --override once a maintainer ' \
                       'confirms the task is abandoned.'
        end
        branch = OwnerTag.branch(@root)
        live = @head.check['live']
        return if branch == pull['branch'] && live && live == pull['head']

        raise Error, "Cannot pick up from this checkout: origin/#{branch} is at #{live || 'nothing'}, but the PR " \
                     "head is #{pull['branch']} at #{pull['head']}."
      end

      def mark(before, event, maintainer, head = nil)
        { 'event' => event, 'owner' => @tag, 'after' => before['id'], 'maintainer' => maintainer || nil,
          'head' => head }.compact
      end

      def post(lead, rows, mark) = @ownership.post(body(lead, rows, mark))

      def settled(comment) = @ownership.state_after(comment['id']) || raise(Error, "#{UNSEEN} #{comment['html_url']}")

      def void(comment, note) = @ownership.edit(comment['id'], "#{comment['body']}\n\n_#{note}_")

      # The winner records its tag, then checks the branch as its new owner.
      def own(url)
        OwnerTag.record(@root, @tag)
        { 'state' => 'picked_up', 'owner' => @tag, 'pickup' => url, 'branch' => @head.check }
      end

      def body(lead, rows, mark)
        table = rows.map { |field, value| "| #{field} | #{PublicationText.table_cell(value)} |" }
        [PublicationText.identity(@content['identity']), "**#{lead}**",
         ['| Field | Value |', '| --- | --- |', *table].join("\n"), Ownership.mark(mark)].join("\n\n")
      end

      def owner_tag
        tag = @content['owner_tag']
        return tag if tag.is_a?(String) && tag.match?(Ownership::TAG)

        raise Error, 'owner_tag must be the WIP Details owner tag: letters, digits, _ or -, up to 40 characters.'
      end

      # The original owner's tag, the last part of the WIP Details Owner, when the description names one.
      def wip_tag(description)
        tag = Handoff::WipNote.value(description, 'owner').to_s.split("\u00B7").last.to_s.strip
        tag if tag.match?(Ownership::TAG) && tag != 'UNKNOWN'
      end
    end
  end
end
