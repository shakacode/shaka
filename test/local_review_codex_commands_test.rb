# frozen_string_literal: true

require_relative 'review_prompt_file_test'
require 'shaka/local_review/codex_commands'

# https://github.com/shakacode/shaka/issues/887: in a container without unprivileged user
# namespaces, Codex's read-only sandbox failed every command, yet the review completed from the
# diff alone. The fixture is that run's `codex exec --json` output, captured in Docker.
class LocalReviewCodexCommandsTest < Minitest::Test
  include ReviewPromptFileFixture

  CAPTURE = File.expand_path('fixtures/codex_sandbox_failure.jsonl', __dir__)

  def test_the_captured_sandbox_failure_ran_one_command_the_sandbox_refused
    assert_equal({ 'ran' => 1, 'succeeded' => 0, 'sandbox_failed' => 1 },
                 Shaka::LocalReviewCodexCommands.summary(File.read(CAPTURE)))
  end

  # A search that finds nothing exits 1 and Codex marks it failed, but the sandbox ran it.
  def test_a_command_that_exits_nonzero_inside_a_working_sandbox_is_not_a_sandbox_failure
    miss = JSON.generate(type: 'item.completed',
                         item: { type: 'command_execution', status: 'failed', exit_code: 1, aggregated_output: '' })

    assert_equal({ 'ran' => 1, 'succeeded' => 0, 'sandbox_failed' => 0 },
                 Shaka::LocalReviewCodexCommands.summary("#{miss}\n"))
  end

  # A review that chose to read only its prompt ran no command, which is not a failure.
  def test_a_completed_command_succeeds_and_a_review_without_commands_reports_nothing
    done = JSON.generate(type: 'item.completed', item: { type: 'command_execution', status: 'completed', exit_code: 0 })

    assert_equal({ 'ran' => 2, 'succeeded' => 1, 'sandbox_failed' => 1 },
                 Shaka::LocalReviewCodexCommands.summary("#{File.read(CAPTURE)}#{done}\n"))
    assert_nil Shaka::LocalReviewCodexCommands.summary("not json\n#{JSON.generate(type: 'turn.completed')}\n")
  end

  def test_a_completed_review_records_its_command_counts
    with_repository do |root, base, head, bin|
      output, error, status = run_review(root, base, head, bin)

      assert_predicate status, :success?, "#{output}\n#{error}"
      result = JSON.parse(output)
      File.unlink(result.fetch('report'))

      assert_equal({ 'ran' => 1, 'succeeded' => 0, 'sandbox_failed' => 1 }, result.fetch('commands'))
    end
  end

  private

  # Replays the captured events on stdout, as `codex exec --json` prints them, then writes the review.
  def fake_codex(bin, head)
    write_executable(bin, 'codex', <<~RUBY)
      #!/usr/bin/env ruby
      STDIN.read
      print File.read(#{CAPTURE.inspect})
      File.write(ARGV.fetch(ARGV.index('-o') + 1),
                 "no findings\\nREVIEWED #{head} BY openai/codex EFFORT UNKNOWN FINDINGS 0\\n")
    RUBY
  end
end
