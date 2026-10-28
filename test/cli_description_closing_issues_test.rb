# frozen_string_literal: true

# Proves description names an issue its summary says it fixes when GitHub will not close it.

require_relative 'test_helper'
require_relative 'cli_opening_check_fakes'
require 'json'

class CliDescriptionClosingIssuesTest < Minitest::Test
  include CliOpeningCheckFakes

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  ROOT = File.expand_path('..', __dir__)
  SUMMARY = 'Fixes #1 and #2.'

  def test_an_unlinked_issue_is_named_after_publication
    Dir.mktmpdir do |dir|
      output, error, status = run_description(dir)

      assert_predicate status, :success?, error
      assert_includes JSON.parse(output).fetch('closing_issues'), 'fixes #2, but GitHub will not close it'
      assert_includes File.read(File.join(dir, 'published.md')), SUMMARY
    end
  end
end
