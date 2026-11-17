# frozen_string_literal: true

require_relative 'support/post_implementation_fixture'

# A checkpoint without --timeout-seconds takes the deadline of the reviewer its settings choose.
class PostImplementationDeadlineTest < Minitest::Test
  include PostImplementationFixture

  def test_the_reviewer_chosen_by_settings_sets_the_default_deadline
    cases = [[{ 'reviewer' => 'anthropic/claude' }, :fake_claude, 600], [{}, :fake_checkpoint, 300]]
    cases.each do |settings, fake, deadline|
      with_repository({ 'checkpoint' => settings }) do |root, base, head, bin|
        send(fake, bin, head)
        result, status = run_checkpoint(root, base, head, bin)
        assert_predicate status, :success?, result.inspect
        assert_equal deadline, result.fetch('timeout_seconds')
      end
    end
  end

  def test_an_explicit_deadline_wins
    with_repository({ 'checkpoint' => { 'reviewer' => 'anthropic/claude' } }) do |root, base, head, bin|
      fake_claude(bin, head)
      result, status = run_checkpoint(root, base, head, bin, '--timeout-seconds', '120')
      assert_predicate status, :success?, result.inspect
      assert_equal 120, result.fetch('timeout_seconds')
    end
  end
end
