# frozen_string_literal: true

require_relative '../error'
require_relative 'rendered_prose'
require_relative 'stored_rendering'

module Shaka
  # When GitHub refuses its Markdown renderer, as Claude Code cloud sessions do, a caller that
  # opts in checks the rendering GitHub stores for its comment instead, and takes back a write
  # that fails. Every other caller still refuses before writing.
  module DeferredRendering
    FULL = 'Accept: application/vnd.github.full+json'

    # GitHub refused `POST /markdown`; nothing was written.
    class Refused < Error; end

    private

    # GitHub's rendering of the text, or nil when the renderer is refused and `stored_check`
    # will check the stored comment after writing. The escape check then reads the source.
    def rendering_before_write(content, verbatim, stored_check)
      verify_rendering(content, verbatim:)
    rescue Refused
      raise unless stored_check

      RenderedProse.source_escapes!(quoted_out(content, verbatim))
      nil
    end

    def checked_after_write(existing, written, target, stored_check)
      stored = written.equal?(existing) ? api(comment_path(written, target), headers: [FULL]) : written
      html = stored['body_html']
      raise Error, 'GitHub returned no stored rendering to check.' unless html.is_a?(String)

      normalized = StoredRendering.normalize(html, written['body'])
      # Stored HTML holds the quoted text too, so its tables are expected as well; a broken one fails closed.
      RenderedProse.tables!(written['body'], normalized)
      stored_check.call(normalized)
      written
    rescue Error => e
      undo(existing, written, target, e)
    end

    # An unchanged comment was already live; a changed one gets its earlier body back, and a new one goes.
    def undo(existing, written, target, error)
      raise Error, "#{error.message} The same text was already published at #{written['html_url']}." if
        written.equal?(existing)

      begin
        take_back(existing, comment_path(written, target))
      rescue Error => e
        raise Error, "#{error.message} Undoing the write failed (#{e.message}); #{written['html_url']} shows it."
      end
      raise Error, "#{error.message} The comment was #{existing ? 'restored' : 'deleted'}."
    end

    def take_back(existing, path)
      return api(path, method: 'PATCH', fields: { body: existing['body'] }) if existing

      capture(['gh', 'api', '--method', 'DELETE', path])
    end

    def comment_path(comment, target)
      "repos/#{@repository}/#{comments_collection(target)}/comments/#{positive_integer(comment['id'])}"
    end
  end
end
