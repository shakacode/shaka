# frozen_string_literal: true

require_relative '../publication/rendering_preview'

module Shaka
  # Checks self-hosted publication rendering after the final description read.
  module HandoffRendering
    private

    def rendering_fact(live)
      return unless RenderingPreview.required?(@github)

      pull = @github.api("repos/#{@github.repository}/pulls/#{@github.number}")
      recheck_head(pull.dig('head', 'sha'), live)
      return note('rendering preview skipped', 'Fork PR: preview code stays unexecuted.') if fork_preview?(pull)

      RenderingPreview.verify_supported!(@github)
      return "rendering preview #{live[0, Handoff::SHORT]}" if RenderingPreview.current?(pull['body'], live)

      owe('rendering preview owed', 'Apply the reviewed rendering to this PR description with ' \
                                    '`description --rendering-preview-root DIR`, then inspect it on GitHub.')
    rescue Error => e
      owe('rendering preview unavailable', e.message)
    end

    def fork_preview?(pull)
      source = pull.dig('head', 'repo', 'full_name')
      source && !source.casecmp?(@github.repository)
    end

    # Every final read checks the head so an intervening push cannot pass as current.
    def recheck_head(moved, live)
      @owed << "PR head moved to #{moved} while handoff read it; run it again." if moved && moved != live
    end
  end
end
