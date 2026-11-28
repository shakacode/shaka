# frozen_string_literal: true

require_relative 'github_helper'
require 'shaka/code_spans'

# GitHub reads three or more backticks as a code span delimiter, so an example meant to show them
# loses them (PR #1331). Each rendering is GitHub's, recorded from POST /markdown and trimmed of attributes.
class CodeSpansTest < Minitest::Test
  include GitHubHelper

  LOST = {
    'Such as ```js``` blocks.' => '<p>Such as <code>js</code> blocks.</p>',
    "    ~~~\nUse ```js``` here." => "<pre><code>~~~\n</code></pre>\n<p>Use <code>js</code> here.</p>",
    'Use \\\\```js``` here.' => '<p>Use \\<code>js</code> here.</p>',
    'Use ```js``` or ```` ```js``` ````.' => '<p>Use <code>js</code> or <code>```js```</code>.</p>'
  }.freeze
  KEPT = {
    'Such as ```` ```js``` blocks ````.' => '<p>Such as <code>```js``` blocks</code>.</p>',
    'Use \\```js``` here.' => '<p>Use ```js``` here.</p>',
    "> ```md\n> ```js```\n> ```" => '<blockquote><pre><span>```</span>js<span>```</span></pre></blockquote>',
    "- ~~~text\n  ```js```\n  ~~~" => "<ul><li><pre><code>```js```\n</code></pre></li></ul>",
    'Use `code` and ``a`b``.' => '<p>Use <code>code</code> and <code>a`b</code>.</p>'
  }.freeze

  def test_an_example_whose_backticks_github_drops_is_refused
    LOST.each do |source, html|
      error = assert_raises(Shaka::Error, source) { Shaka::CodeSpans.check!(source, html) }
      assert_includes error.message, 'GitHub renders ```js``` as inline code', source
    end
  end

  def test_backticks_github_keeps_are_accepted
    KEPT.each { |source, html| Shaka::CodeSpans.check!(source, html) }
  end

  def test_the_description_is_refused_before_the_pull_request_is_edited
    source, html = LOST.first
    github = client(response({ 'id' => 1, 'body' => '', 'additions' => 4, 'deletions' => 2 }), html_response(html))

    assert_raises(Shaka::Error) { github.description(body: "#{source}\n") }
    assert_equal 2, @calls.size
    assert_includes JSON.parse(@calls.last[1])['text'], source
  end

  # A person's text outside Shaka's region is theirs; only the region is rendered for this check.
  def test_text_outside_the_region_is_not_checked
    person = "#{LOST.keys.first}\n\n"
    github = client(response({ 'id' => 1, 'body' => person, 'additions' => 4, 'deletions' => 2 }),
                    html_response('<p>Summary.</p>'))

    error = assert_raises(RuntimeError) { github.description(body: "Summary.\n") }
    assert_equal 'Unexpected GitHub request', error.message
    refute_includes JSON.parse(@calls[1][1])['text'], person.strip
  end
end
