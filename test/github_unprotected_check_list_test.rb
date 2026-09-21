# frozen_string_literal: true

require_relative 'github_helper'

class GitHubUnprotectedCheckListTest < Minitest::Test
  include GitHubHelper

  def test_required_checks_treat_the_unprotected_diagnostic_as_an_empty_list
    message = "no required checks reported on the 'main' branch\n"
    assert_empty client(['', message, STATUS.new(1)]).required_checks
  end

  def test_checks_treat_the_no_checks_diagnostic_as_an_empty_list
    message = "no checks reported on the 'main' branch\n"
    assert_empty client(['', message, STATUS.new(1)]).checks
  end

  def test_required_checks_keep_a_truncated_diagnostic_as_unavailable
    error = assert_raises(Shaka::Error) do
      client(['', 'no required checks reported', STATUS.new(1)]).required_checks
    end
    assert_match(/Required-check evidence is unavailable/, error.message)
  end

  def test_required_checks_keep_extra_stderr_as_unavailable
    stderr = "no required checks reported on the 'main' branch\nHTTP 503 while querying checks\n"
    error = assert_raises(Shaka::Error) do
      client(['', stderr, STATUS.new(1)]).required_checks
    end
    assert_match(/Required-check evidence is unavailable/, error.message)
  end

  def test_required_checks_keep_malformed_json_as_unavailable
    error = assert_raises(Shaka::Error) do
      client(['broken JSON', 'private stderr', STATUS.new(0)]).required_checks
    end
    assert_match(/Required-check evidence is unavailable/, error.message)
  end
end
