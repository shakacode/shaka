# frozen_string_literal: true

require_relative 'usage_archive'
require_relative '../prose_limits'
require_relative '../publication/deferred_rendering'
require_relative '../publication/rendered_prose'
require_relative '../publication/stored_rendering'

module Shaka
  # GitHub write guards stay outside the previewable publication renderers.
  module DescriptionPublishing
    CHECKED_AFTER = 'checked after writing, because GitHub refused its Markdown renderer'
    # GitHub drops the region markers from its stored rendering, so only a body that is all Shaka text can be measured.
    PROSE_UNCHECKED = "#{CHECKED_AFTER}; prose limits not checked, because text outside Shaka's region " \
                      'cannot be told apart in the stored rendering'.freeze

    # A block builds the body from the pull request it replaces, using this same read. With `deferred`, a
    # refused renderer moves the checks to the rendering GitHub stores, and a failing write is undone.
    # `writer`, called after the block, gives the four-field identity line that signs any usage archive comments.
    # `supplied`, called after the block, gives the author's content, so the length limit counts only its prose.
    def description(body: nil, prose: ProseLimits.new, deferred: false, writer: nil, supplied: nil)
      current = pull
      archive = UsageArchive.new(self)
      readable = archive_pull(current, archive)
      rendered = publishable(block_given? ? yield(readable) : body)
      prose = measured(prose, supplied)
      plan = description_plan(archive, current, rendered, writer&.call)
      merged, checked = publish_archive(plan, current, prose, deferred)
      return confirmed(api(pull_path, method: 'PATCH', fields: { body: merged }), merged) if checked

      checked_description(current, merged, prose)
    end

    private

    def measured(prose, supplied) = supplied ? prose.with_supplied(supplied.call) : prose

    def description_plan(archive, current, rendered, writer)
      base = MergeWarningRegion.answered_by_merge(current['body'].to_s, @repository, current)
      archive.prepare(merge(base, rendered), writer:)
    end

    # Returns the body to write and whether GitHub's renderer checked it.
    def publish_archive(plan, current, prose, deferred)
      checked = rendered_before_write?(plan.preview, current, prose, deferred)
      check_unchanged(current['body'].to_s, current)
      merged = check_length(plan.publish)
      return [merged, checked] if merged == plan.preview

      checked ? verify_rendering(merged) : RenderedProse.source_escapes!(merged)
      check_unchanged(current['body'].to_s, current)
      [merged, checked]
    end

    def rendered_before_write?(preview, current, prose, deferred)
      prose.verify_publication!(self, Publishing.managed_region(preview), kind: :description, pull: current)
      verify_rendering(preview)
      true
    rescue DeferredRendering::Refused
      raise unless deferred

      RenderedProse.source_escapes!(preview)
      false
    end

    # A write whose answer is lost may still have landed, so it is read back and undone like a failed check.
    def checked_description(current, merged, prose)
      written = api(pull_path, method: 'PATCH', fields: { body: merged }, headers: [DeferredRendering::FULL])
      confirmed(written, merged)
      html = written['body_html']
      raise Error, 'GitHub returned no stored rendering to check.' unless html.is_a?(String)

      normalized = StoredRendering.normalize(html, merged)
      RenderedProse.check!(merged, normalized)
      written.except('body_html', 'body_text').merge('rendering' => stored_prose(prose, merged, normalized, current))
    rescue StandardError => e # any failure after the write, not only a check's, restores the earlier body
      restore_description(current, merged, e)
    end

    def stored_prose(prose, merged, html, current)
      return PROSE_UNCHECKED unless only_region?(merged)

      prose.verify!(html, kind: :description, changed_lines: ProseLimits.changed_lines(current))
      CHECKED_AFTER
    end

    # Comments and whitespace outside the region render as nothing.
    def only_region?(body)
      text = Publishing.without_archive_guard(body)
      region = Publishing.managed_region(text)
      region && only_comments?(text.sub("#{Publishing::OPEN_MARK}#{region}#{Publishing::CLOSE_MARK}", ''))
    end

    # Each comment ends at its first `-->`, as HTML ends it, so text between two comments stays visible.
    def only_comments?(text)
      rest = text.lstrip
      until rest.empty?
        close = rest.start_with?('<!--') && rest.index('-->', 2)
        return false unless close

        rest = rest[(close + 3)..].lstrip
      end
      true
    end

    def restore_description(current, merged, error)
      earlier = current['body'].to_s
      url = current['html_url']
      raise Error, "#{error.message} The same description was already published at #{url}." if earlier == merged

      begin
        outcome = put_back(earlier, merged)
      rescue Error => e
        raise Error, "#{error.message} Restoring the earlier description failed (#{e.message}); inspect #{url}."
      end
      raise Error, "#{error.message} The earlier description #{outcome}."
    end

    # A body edited after this write is someone else's now, so it is left for a person to inspect. GitHub offers
    # no compare-and-swap, so an edit landing between this read and the restore is still overwritten.
    def put_back(earlier, merged)
      live = pull['body'].to_s
      return 'is still in place' if live == earlier
      raise Error, 'it changed after this write' unless [merged, Publishing.as_stored(merged)].include?(live)

      api(pull_path, method: 'PATCH', fields: { body: earlier })
      'was restored'
    end

    def archive_pull(current, archive)
      head = current.dig('head', 'repo', 'full_name')
      return current unless head && head == current.dig('base', 'repo', 'full_name')

      current.merge('body' => archive.expand(current['body'].to_s))
    end
  end
end
