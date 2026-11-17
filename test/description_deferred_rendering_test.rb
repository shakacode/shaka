# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/github'

# A description published where GitHub refuses `POST /markdown`, as Claude Code cloud sessions do.
class DescriptionDeferredRenderingTest < Minitest::Test
  FULL = 'Accept: application/vnd.github.full+json'
  REGION = "<!-- shaka:begin -->\nOlder.<!-- shaka:end -->"

  # One pull request whose renderer is refused; GitHub stores `html` for whatever body is written.
  class RefusedRendererGitHub < Shaka::GitHub
    attr_accessor :html, :edit_after_write
    attr_reader :patches, :body

    def initialize(body)
      super('owner/repo', 42)
      @body = body
      @html = '<p>Fine.</p>'
      @patches = []
    end

    def api(path, method: 'GET', fields: {}, headers: [])
      raise Shaka::Error, "Unexpected #{method} #{path}" unless path == 'repos/owner/repo/pulls/42'
      return pull_json if method == 'GET'

      @patches << [fields.fetch(:body), headers]
      @body = fields.fetch(:body)
      written = pull_json.merge(headers.include?(FULL) ? { 'body_html' => @html, 'body_text' => 'Fine.' } : {})
      @body = 'A person edited this.' if edit_after_write
      written
    end

    def markdown(_text) = raise(Shaka::DeferredRendering::Refused, 'GitHub refused its Markdown renderer.')

    private

    def pull_json
      repo = { 'full_name' => repository }
      { 'number' => 42, 'body' => @body, 'html_url' => 'https://github.com/owner/repo/pull/42',
        'additions' => 10, 'deletions' => 2, 'head' => { 'sha' => 'a' * 40, 'repo' => repo },
        'base' => { 'sha' => 'b' * 40, 'repo' => repo } }
    end
  end

  def publish(github, body = 'Summary.', **)
    github.description(body:, deferred: true, **)
  end

  def test_a_refused_renderer_writes_once_and_checks_the_stored_rendering
    github = RefusedRendererGitHub.new(REGION)
    written = publish(github)

    assert_equal [[FULL]], github.patches.map(&:last)
    assert_includes github.body, "<!-- shaka:begin -->\nSummary."
    assert_nil written['body_html']
    assert_equal Shaka::DescriptionPublishing::CHECKED_AFTER, written['rendering']
  end

  def test_without_the_opt_in_a_refused_renderer_writes_nothing
    github = RefusedRendererGitHub.new(REGION)

    assert_raises(Shaka::DeferredRendering::Refused) { github.description(body: 'Summary.') }
    assert_empty github.patches
  end

  def test_an_escape_in_the_source_is_refused_before_writing
    github = RefusedRendererGitHub.new(REGION)

    error = assert_raises(Shaka::Error) { publish(github, 'Line one\\nline two.') }
    assert_equal Shaka::RenderedProse::ESCAPED, error.message
    assert_empty github.patches
  end

  def test_a_stored_rendering_that_fails_a_check_restores_the_earlier_body
    github = RefusedRendererGitHub.new(REGION)
    github.html = '<p>no table</p>'

    error = assert_raises(Shaka::Error) { publish(github, "| a |\n| --- |\n| b |") }
    assert_match(/rendered 0 of 1 table.* The earlier description was restored\.\z/, error.message)
    assert_equal REGION, github.body
  end

  def test_prose_limits_measure_the_stored_rendering_of_an_all_shaka_body
    github = RefusedRendererGitHub.new(REGION)
    github.html = '<p>One two three four five six.</p>'

    error = assert_raises(Shaka::Error) { publish(github, prose: Shaka::ProseLimits.new('max_sentence_words' => 3)) }
    assert_match(/a sentence has 6 words.* The earlier description was restored\.\z/, error.message)
    assert_equal REGION, github.body
  end

  def test_text_outside_the_region_leaves_prose_limits_unchecked_and_says_so
    github = RefusedRendererGitHub.new("A person wrote this.\n\n#{REGION}")
    github.html = '<p>One two three four five six.</p>'
    written = publish(github, prose: Shaka::ProseLimits.new('max_sentence_words' => 3))

    assert_equal Shaka::DescriptionPublishing::PROSE_UNCHECKED, written['rendering']
    assert_includes github.body, 'A person wrote this.'
  end

  # Comments render as nothing, so they leave the body all Shaka text. An unclosed comment, or text
  # between two comments, does not.
  def test_only_whole_comments_outside_the_region_keep_prose_limits_checked
    checked = Shaka::DescriptionPublishing::CHECKED_AFTER
    unchecked = Shaka::DescriptionPublishing::PROSE_UNCHECKED
    { "<!-- note -->\n#{REGION}" => checked, "<!-- open\n#{REGION}" => unchecked,
      "<!-- a -->\nA person wrote this.\n<!-- b -->\n#{REGION}" => unchecked }.each do |body, rendering|
      assert_equal rendering, publish(RefusedRendererGitHub.new(body))['rendering']
    end
  end

  def test_a_body_edited_after_the_write_is_left_for_a_person
    github = RefusedRendererGitHub.new(REGION)
    github.html = '<p>Line\\n</p>'
    github.edit_after_write = true

    error = assert_raises(Shaka::Error) { publish(github) }
    assert_match(/Restoring the earlier description failed \(it changed after this write\); inspect/, error.message)
    assert_equal 1, github.patches.size
  end

  def test_an_unchanged_description_that_fails_says_it_was_already_published
    github = RefusedRendererGitHub.new("<!-- shaka:begin -->\nSummary.<!-- shaka:end -->")
    github.html = '<p>Line\\n</p>'

    error = assert_raises(Shaka::Error) { publish(github) }
    assert_match(/already published at/, error.message)
    assert_equal 1, github.patches.size
  end
end
