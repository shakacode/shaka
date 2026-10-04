# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/walkthrough/history'

class ArchiveRenderingTest < Minitest::Test
  def test_nested_disclosures_and_escaped_code_stay_within_the_outer_archive
    html = '<p>Current review link.</p><details><summary>Archive</summary>' \
           '<details open=""><summary>Evidence</summary><p>Kept.</p></details>' \
           '<pre><code>&lt;/details&gt;</code></pre></details>'

    Shaka::WalkthroughText.verify_archive!(html)
  end

  def test_premature_closing_missing_wrapper_and_unclosed_wrapper_are_rejected
    ['<details></details><p>Outside.</p>', '<p>No archive.</p>', '<details><p>Unclosed.</p>',
     '</details><details></details>', '<details></details><details></details>'].each do |html|
      assert_raises(Shaka::Error) { Shaka::WalkthroughText.verify_archive!(html) }
    end
  end

  def test_an_attestation_can_follow_the_archive_but_other_prose_cannot
    footer = "REVIEWED #{'a' * 40} BY openai/codex EFFORT medium FINDINGS 0"
    html = "<details><p>Report.</p></details>\n<p>#{footer}</p>\n"

    Shaka::WalkthroughText.verify_archive!(html, footer:)
    assert_raises(Shaka::Error) do
      Shaka::WalkthroughText.verify_archive!(html.sub('</details>', '</details><p>Outside.</p>'), footer:)
    end
    assert_raises(Shaka::Error) { Shaka::WalkthroughText.verify_archive!(html, footer: 'Different footer') }
  end
end
