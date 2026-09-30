# frozen_string_literal: true

require_relative '../walkthrough/history'

module Shaka
  # Keeps this account's older checkpoint comments linked to its newest execution.
  class PostImplementationHistory
    MARKER = 'Superseded — read the current product validation:'
    KEY = /\A<!-- shaka:reply:post-implementation-[0-9a-f]{7}-[0-9a-f]{8} -->\n/

    def initialize(github) = @github = github

    def collapse(published)
      report = { 'collapsed' => [], 'unavailable' => [] }
      comments = checkpoint_comments(published)
      latest = comments.max_by { |comment| order(comment) }
      comments.reject { |comment| comment['id'] == latest['id'] }.each do |comment|
        fold_one(comment, latest['id'], report)
      end
      report
    rescue Error => e
      report['unavailable'] << e.message
      report
    end

    private

    def checkpoint_comments(published)
      @account = @github.viewer_login
      raise Error, 'Authenticated GitHub login is unavailable.' unless @account.is_a?(String) && !@account.empty?

      comments = @github.issue_comments.select { |comment| owned?(comment) }
      raise Error, 'Published checkpoint is absent from comment listing.' unless
        comments.any? { |comment| comment['id'] == published['id'] }

      comments
    end

    def owned?(comment)
      comment.dig('user', 'login') == @account && comment['body'].to_s.match?(KEY)
    end

    def order(comment)
      time = WalkthroughText.submitted_at(comment.merge('submitted_at' => comment['created_at']))
      id = comment['id']
      raise Error, 'Checkpoint comment has no creation time or identifier.' unless
        time && id.is_a?(Integer) && id.positive?

      [time, id]
    end

    def fold_one(comment, latest, report)
      path = "repos/#{@github.repository}/issues/comments/#{comment.fetch('id')}"
      source = fresh_body(path)
      body = revised_body(source, latest)
      return unless body && body != source

      replace(path, source, body)
      report['collapsed'] << comment['id']
    rescue Error => e
      report['unavailable'] << "Comment #{comment['id']}: #{e.message}"
    end

    def fresh_body(path)
      source = @github.api(path)
      raise Error, 'Checkpoint changed before collapse.' unless owned?(source)

      source.fetch('body')
    end

    def revised_body(body, latest)
      mark, content = body.split("\n", 2)
      revised = if content.start_with?("#{MARKER} ")
                  retarget(content, latest)
                else
                  wrap(content, latest)
                end
      "#{mark}\n#{revised}" if revised
    end

    def retarget(content, latest)
      pointer = /\A#{Regexp.escape(MARKER)} #{Regexp.escape(url_prefix)}(\d+)(?=\n|\z)/
      match = content.match(pointer) || raise(Error, 'Collapsed checkpoint pointer is malformed.')
      # An overlapping publication may already have linked a newer comment.
      return if match[1].to_i >= latest

      content.sub(pointer, "#{MARKER} #{url_prefix}#{latest}")
    end

    def wrap(content, latest)
      archived = WalkthroughText.archive(content.rstrip)
      "#{MARKER} #{url_prefix}#{latest}\n\n<details>\n<summary>Earlier product validation</summary>\n\n" \
        "#{archived}\n\n</details>\n"
    end

    def replace(path, source, body)
      @github.verify_rendering(body)
      raise Error, 'Checkpoint body changed before update.' unless @github.api(path)['body'] == source

      @github.api(path, method: 'PATCH', fields: { body: })
      return if @github.api(path)['body'] == body

      raise Error, 'Stored checkpoint body does not match the collapsed report.'
    end

    def url_prefix = "https://github.com/#{@github.repository}/pull/#{@github.number}#issuecomment-"
  end
end
