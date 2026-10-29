# frozen_string_literal: true

require_relative 'publication_test'

# https://github.com/shakacode/shaka/issues/887: a Codex review whose every command failed still
# folded into "local review completed", though it had read only the diff in its prompt.
class PublicationBlindReviewTest < Minitest::Test
  HEAD = "abcdef1#{'0' * 33}".freeze
  VALIDATE = { 'kind' => 'validation', 'command' => 'validate', 'status' => 'completed', 'exit_code' => 0 }.freeze
  CODEX = { 'kind' => 'review', 'reviewer' => 'openai/codex', 'status' => 'completed', 'head' => HEAD }.freeze
  BLIND = CODEX.merge('commands' => { 'ran' => 3, 'succeeded' => 0, 'sandbox_failed' => 3 }).freeze
  GAPS = '**Setup gaps:**'

  def render(*reviews)
    checks = { 'validation' => [VALIDATE], 'review' => reviews }.transform_values do |results|
      results.map { |result| { 'status' => 'bound', 'original' => result } }
    end
    settings = Shaka::PublicationSettings.new(verdict: { 'status' => 'ready', 'head' => HEAD, 'checks' => checks })
    Shaka::Publication.description(PublicationRegressionTest.new(name).description_content, nil, nil, settings)
  end

  def test_a_reviewer_whose_sandbox_refused_every_command_unfolds_the_line_and_is_named
    rendered = render(BLIND, BLIND)

    assert_includes rendered, "## Verification\n\n**Validation and review:** `validate` passed (exit 0)"
    assert_includes rendered, "#{GAPS} `openai/codex` could not start its sandbox, so it reviewed only the diff ([why]("
  end

  # A review that ran some commands, failed searches the sandbox still ran, or none at all read
  # what it chose to read.
  def test_a_review_whose_sandbox_ran_its_commands_stays_folded
    some = CODEX.merge('commands' => { 'ran' => 3, 'succeeded' => 1, 'sandbox_failed' => 0 })
    misses = CODEX.merge('commands' => { 'ran' => 2, 'succeeded' => 0, 'sandbox_failed' => 0 })

    [render(some), render(misses), render(CODEX)].each do |rendered|
      assert_includes rendered, "## Verification\n\nValidation passed; local review completed at abcdef1."
      refute_includes rendered, GAPS
    end
  end
end
