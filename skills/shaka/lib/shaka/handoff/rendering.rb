# frozen_string_literal: true

require_relative '../publication/rendering_preview'

module Shaka
  # Checks self-hosted publication rendering after the final description read.
  module HandoffRendering
    private

    def rendering_fact(live)
      note_kept_installed
      required = RenderingPreview.required?(@github)
      no_preview = RenderingPreview.no_preview(@github)
      preview_fact(live, required, no_preview) if required || no_preview.any?
    rescue Error => e
      owe('rendering preview unavailable', e.message)
    end

    def preview_fact(live, required, no_preview)
      pull = @github.api("repos/#{@github.repository}/pulls/#{@github.number}")
      recheck_head(pull.dig('head', 'sha'), live)
      return note('rendering preview skipped', 'Fork PR: preview code stays unexecuted.') if fork_preview?(pull)

      note_no_preview(no_preview)
      return unless required
      return "rendering preview #{live[0, Handoff::SHORT]}" if RenderingPreview.current?(pull['body'], live)

      owe('rendering preview owed', 'Apply the reviewed rendering to this PR description with ' \
                                    '`description --rendering-preview-root DIR`, then inspect it on GitHub.')
    end

    # A changed guard or GitHub write stays installed, so the preview, current or owed, does not show its change.
    def note_kept_installed
      paths = RenderingPreview.kept_installed(@github)
      @notes << "Kept installed, not previewed: #{paths.join(', ')}." unless paths.empty?
    end

    # Nothing can settle these, so they are never owed. Fork file names stay out: a note reads as the helper's words.
    def note_no_preview(paths)
      @notes << "No preview exists for #{paths.join(', ')}. Say on the PR how you checked its rendering." if paths.any?
    end

    # A deleted fork reports no head repository; only a named match counts as the same repository.
    def fork_preview?(pull) = !pull.dig('head', 'repo', 'full_name').to_s.casecmp?(@github.repository)

    # Every final read checks the head so an intervening push cannot pass as current.
    def recheck_head(moved, live)
      @owed << "PR head moved to #{moved} while handoff read it; run it again." if moved && moved != live
    end
  end
end
