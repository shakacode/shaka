# frozen_string_literal: true

# Proves a published description names the commit of the helper that rendered it.

require_relative 'test_helper'
require_relative 'repository_fixture'
require_relative 'cli_opening_check_fakes'
require 'json'
require 'shaka/version'

class CliDescriptionWorkflowVersionTest < Minitest::Test
  include RepositoryConfigTestHelpers
  include CliOpeningCheckFakes

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  ROOT = File.expand_path('..', __dir__)
  SUMMARY = 'Descriptions name the commit that rendered them.'

  # Break: every commit between releases published the same `0.1.0.pre.1`.
  def test_a_direct_checkout_publishes_its_head_commit
    head, found = Open3.capture2(TEST_GIT, '-C', ROOT, 'rev-parse', 'HEAD')
    skip 'this source tree is not a Git checkout' unless found.success?

    Dir.mktmpdir do |dir|
      _output, error, status = run_description(dir)

      assert_predicate status, :success?, error
      link = "[`#{head[0, 7]}`](https://github.com/shakacode/shaka/commit/#{head.strip})"
      assert_match(/\| Workflow version \| #{Regexp.escape(link)}( \(modified\))? \|/,
                   File.read(File.join(dir, 'published.md')))
    end
  end
end
