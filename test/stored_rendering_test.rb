# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/publication/stored_rendering'

# GitHub stores a comment's HTML with repository links and wrappers that `POST /markdown` leaves out.
class StoredRenderingTest < Minitest::Test
  SHA = '1b571dcae4588c9866a3e0af9523d860dba67175'

  def commit_link(shown) = %(<a class="commit-link" href="https://github.com/o/r/commit/#{SHA}"><tt>#{shown}</tt></a>)

  def test_commit_links_return_to_the_sha_as_the_source_wrote_it
    source = "Round 1 · 1b571dc\n\nREVIEWED #{SHA} BY x"
    stored = %(<summary dir="auto">Round 1 · #{commit_link('1b571dc')}</summary><p dir="auto">REVIEWED ) +
             "#{commit_link('1b571dc')} BY x</p>"

    assert_equal "<summary>Round 1 · 1b571dc</summary><p>REVIEWED #{SHA} BY x</p>",
                 Shaka::StoredRendering.normalize(stored, source)
  end

  def test_shas_in_code_link_targets_and_comments_are_not_what_github_linked
    source = "<!-- key-1b571dcae458 -->\n[`1b571dc`](https://github.com/o/r/commit/#{SHA}) then #{SHA}"
    stored = "<p>then #{commit_link('1b571dc')}</p>"

    assert_equal "<p>then #{SHA}</p>", Shaka::StoredRendering.normalize(stored, source)
  end

  def test_a_sha_inside_an_indented_tilde_fence_is_not_what_github_linked
    source = "   ~~~\n   REVIEWED 1b571dc BY x\n   ~~~\n\nREVIEWED #{SHA} BY x"
    stored = "<pre><code>REVIEWED 1b571dc BY x</code></pre><p>REVIEWED #{commit_link('1b571dc')} BY x</p>"

    assert_includes Shaka::StoredRendering.normalize(stored, source), "<p>REVIEWED #{SHA} BY x</p>"
  end

  def test_issue_links_and_mentions_keep_their_text
    stored = '<p><a class="issue-link js-issue-link" href="x">#12</a> <a class="user-mention" href="y">@sam</a></p>'

    assert_equal '<p>#12 @sam</p>', Shaka::StoredRendering.normalize(stored, '#12 @sam')
  end
end
