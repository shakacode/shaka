# frozen_string_literal: true

require 'digest'
require_relative '../error'
require_relative 'managed_region'
require_relative '../public_comments/bounded_list'

module Shaka
  # A merge queue that copies the PR description into its commit takes no message, so the
  # description holds the prepared message while the queue builds the commit. The text around
  # Shaka's region waits in a comment; the next `description` publication puts it back.
  module QueuedDescription
    PARK_MARK = '<!-- shaka:queued-description -->'
    PARKED = %r{\A#{Regexp.escape(PARK_MARK)}\n<!-- body ([A-Za-z0-9+/]*={0,2}) -->\n<!-- queued (\h{64}) -->\n}
    COMMENT_LIMIT = 65_536
    COMMENT_PAGES = 20
    NOTICE = '**Description parked for the merge queue.** This queue copies the PR description into its ' \
             'commit, so the description holds the prepared commit message until the PR merges or leaves ' \
             'the queue. Publishing the description again brings the rest back.'

    # Parks the description, or what an earlier enqueue parked, then writes the message body in its
    # place. The PR title stays: the queue already takes the commit title from it. Returns the URL.
    def queue_description(message)
      body = pull['body'].to_s
      earlier = body.include?(Publishing::OPEN_MARK) ? [] : parked_descriptions
      url = park(earlier.empty? ? body : restored(earlier.last, body), message.prose)
      release_parked(earlier)
      confirmed(api(pull_path, method: 'PATCH', fields: { body: message.prose }), message.prose)
      url
    end

    private

    # Yields the body to publish around: the parked one when the description still holds a queued
    # commit message. The parking comments go once the restored description is stored.
    def restoring(existing)
      parked = unparked_description(existing)
      yield(parked ? parked['body'] : existing).tap { release_parked(parked['comments']) if parked }
    end

    # The text around Shaka's region, which the next publication fills again, and a digest of the
    # message written in its place, so an edit made while the PR is queued is kept.
    def park(body, queued)
      text = "#{PARK_MARK}\n<!-- body #{[outside_region(body)].pack('m0')} -->\n" \
             "<!-- queued #{digest(queued)} -->\n#{NOTICE}\n"
      raise Error, 'The description outside Shaka\'s region is too long to park for the merge queue.' if
        text.length > COMMENT_LIMIT

      posted = api("repos/#{@repository}/issues/#{@number}/comments", method: 'POST', fields: { body: text })
      confirmed(posted, text)['html_url']
    end

    def outside_region(body)
      return body unless body.include?(Publishing::OPEN_MARK) || body.include?(Publishing::CLOSE_MARK)

      region = Publishing.managed_region(body)
      raise Error, 'The description has an ambiguous or malformed managed region; repair it before merging.' unless
        region

      body.sub("#{Publishing::OPEN_MARK}#{region}#{Publishing::CLOSE_MARK}",
               "#{Publishing::OPEN_MARK}\n#{Publishing::CLOSE_MARK}")
    end

    # The parked text and its comments, when the description still holds a queued commit message.
    # Restoring while the PR is queued would let a rebuilt queue commit copy the whole description.
    def unparked_description(existing)
      return if existing.include?(Publishing::OPEN_MARK) || existing.strip.empty?

      comments = parked_descriptions
      return if comments.empty?
      if snapshot['isInMergeQueue'] == true
        raise Error, 'The PR is in the merge queue and its description holds the prepared commit message; ' \
                     'publish the description after the PR merges or leaves the queue.'
      end

      { 'body' => restored(comments.last, existing), 'comments' => comments }
    end

    # The parked text, followed by the live description when someone changed the message since.
    def restored(comment, live)
      encoded, queued = comment['body'].to_s.gsub("\r\n", "\n").match(PARKED).captures
      text = encoded.unpack1('m0').force_encoding(Encoding::UTF_8)
      digest(live) == queued ? text : "#{text}\n\n#{live}"
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
