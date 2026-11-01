# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require_relative 'cli_opening_check_fakes'
require 'json'
require 'rbconfig'

# The description command sends what a reader sees to the opening reviewer and returns its advice.
class CliOpeningTermsTest < Minitest::Test
  include RepositoryConfigTestHelpers
  include CliOpeningCheckFakes

  COMMAND = SHAKA_COMMAND
  ROOT = File.expand_path('..', __dir__)
  SUMMARY = 'Maintainers see their reviewed commit named on the PR.'
  TERM = { term: 'attestation', where: 'Leaves out', plain_wording: 'signed record' }.freeze

  def test_description_reports_a_term_from_prose_the_reader_sees
    with_published_description do |output, _prompt|
      assert_includes output.dig('opening', 'reason'), '"attestation" in Leaves out'
    end
  end

  def test_description_sends_visible_prose_and_leaves_out_what_a_reader_must_open
    with_published_description do |_output, prompt|
      assert_includes prompt, "Why: #{INTENT['why']}"
      assert_includes prompt, "Leaves out: #{INTENT['leaves_out']}"
      refute_includes prompt, VERIFICATION['checks'].first
      refute_includes prompt, 'Review effort'
    end
  end

  private

  def with_published_description
    with_repository do |root|
      commit(root)
      Dir.mktmpdir do |dir|
        output, error, status = run_description(dir, root:, reviewer: 'anthropic/claude') do
          File.write(File.join(dir, 'unclear-terms.json'), JSON.generate([TERM]))
        end
        assert_predicate status, :success?, error
        yield JSON.parse(output), File.read(File.join(dir, 'opening-prompt.txt'))
      end
    end
  end
end
