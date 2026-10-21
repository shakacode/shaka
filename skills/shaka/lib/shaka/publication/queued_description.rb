# frozen_string_literal: true

require 'digest'
require 'zlib'
require_relative '../error'
require_relative 'managed_region'
require_relative '../public_comments/bounded_list'

module Shaka
  # A merge queue that copies the PR description into its commit takes no message, so the
  # description holds the prepared message while the queue builds the commit. The description
  # waits in a comment meanwhile, and every `description` publication reads it from there.
  module QueuedDescription
    PARK_MARK = '<!-- shaka:queued-description -->'
    PARKED = %r{\A#{Regexp.escape(PARK_MARK)}\n<!-- body ([A-Za-z0-9+/]*={0,2}) -->\n<!-- queued (\h{64}) -->\n}
    COMMENT_LIMIT = 65_536
    COMMENT_PAGES = 20
    NOTICE = '**Description parked for the merge queue.** This queue copies the PR description into its ' \
             'commit, so the description holds the prepared commit message until the PR merges or leaves ' \
             'the queue. Publishing the description again brings it back.'

    # Parks the description, or what an earlier enqueue parked, then writes the message body in its
    # place. The PR title stays: the queue already takes the commit title from it. Returns the URL.
    def queue_description(message)
      current = pull
      body = current['body'].to_s
      earlier = parked_around(body)
      parking = park(whole(body, earlier), message.prose)
      unparking_on_failure(parking) do
        check_unchanged(current)
        confirmed(api(pull_path, method: 'PATCH', fields: { body: message.prose }), message.prose)
      end
      # The earlier copies go only once the new one holds the description and the message is in place.
      release_parked(earlier)
      parking['html_url']
    end

    private

    # The pull request as publication should read it, with the parked description in place of a
    # queued commit message, and the parking comments to delete once the restored body is stored.
    # Restoring while the PR is queued would let a rebuilt queue commit copy the whole description.
    # A queued description without Shaka's region may hold a commit message someone else parked, or
    # be the one the queue copies, so it is never published over. An empty description on a PR
    # without comments is a new PR's, so its first publication makes no extra request.
    def unparked(current)
      body = current['body'].to_s
      count = current['comments'].to_i
      return [current, []] if body.include?(Publishing::OPEN_MARK) || (body.strip.empty? && count.zero?)

      refuse_while_queued
      comments = count.zero? ? [] : parked_descriptions
      [comments.empty? ? current : current.merge('body' => whole(body, comments)), comments]
    end

    def refuse_while_queued
      return unless snapshot['isInMergeQueue'] == true

      raise Error, 'The PR is in the merge queue and its description may hold the prepared commit message; ' \
                   'publish the description after the PR merges or leaves the queue.'
    end

    # This account's parking comments, when the description has no Shaka region to hold.
    def parked_around(body) = body.include?(Publishing::OPEN_MARK) ? [] : parked_descriptions

    # The real description: the live one, or what was parked, followed by the live body when
    # someone changed the message since. An emptied description changes nothing parked.
    def whole(body, parked)
      return body if parked.empty?

      encoded, queued = parked.last['body'].to_s.gsub("\r\n", "\n").match(PARKED).captures
      text = inflate(encoded, parked.last)
      digest(body) == queued || body.strip.empty? ? text : "#{text}\n\n#{body}"
    end

    def inflate(encoded, comment)
      Zlib::Inflate.inflate(encoded.unpack1('m0')).force_encoding(Encoding::UTF_8)
    rescue ArgumentError, Zlib::Error
      raise Error, "Parking comment #{comment['html_url'] || comment['id']} is damaged; restore the description " \
                   'from it by hand, then delete it.'
    end

    # The whole description, compressed, and a digest of the message written in its place.
    def park(body, queued)
      text = "#{PARK_MARK}\n<!-- body #{[Zlib::Deflate.deflate(body)].pack('m0')} -->\n" \
             "<!-- queued #{digest(queued)} -->\n#{NOTICE}\n"
      raise Error, 'The description is too long to park for the merge queue.' if text.length > COMMENT_LIMIT

      posted = api("repos/#{@repository}/issues/#{@number}/comments", method: 'POST', fields: { body: text })
      confirmed(posted, text)
    end

    # An edit that landed while the comment was posted is in neither copy, and a failed write leaves
    # the description in place, so either way the swap stops and takes its comment back.
    def unparking_on_failure(parking)
      yield
    rescue Error
      release_parked([parking])
      raise
    end

    # GitHub's web editor stores CRLF line endings, which change no text.
    def digest(text) = Digest::SHA256.hexdigest(text.to_s.gsub("\r\n", "\n").strip)

    def release_parked(comments)
      comments.each do |comment|
        capture(['gh', 'api', "repos/#{@repository}/issues/comments/#{positive_integer(comment['id'])}",
                 '--method', 'DELETE'])
      end
    end

    # Only a comment this account wrote, opening with the parked text, is one this module wrote.
    # The account is read only when a comment carries the mark, the rare case.
    def parked_descriptions
      marked = PublicComments::BoundedList.new(self, max_pages: COMMENT_PAGES, label: 'Comment listing')
                                          .call("repos/#{@repository}/issues/#{@number}/comments")
                                          .select do |comment|
        comment['id'].is_a?(Integer) && comment['body'].to_s.gsub("\r\n", "\n").match?(PARKED)
      end
      return marked if marked.empty?

      account = viewer
      marked.select { |comment| comment.dig('user', 'login') == account }
    end
  end
end
