# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/workflow_version'

class WorkflowVersionMarkdownTest < Minitest::Test
  VERSION = Shaka::VERSION
  SHA = 'a' * 40

  def result(commit, modified: false) = Shaka::WorkflowVersion::Result.new(version: VERSION, commit:, modified:)

  def test_a_known_commit_renders_as_a_link_without_the_version_number
    assert_equal "[`aaaaaaa`](https://github.com/shakacode/shaka/commit/#{SHA})", result(SHA).markdown
    assert_equal "[`aaaaaaa`](https://github.com/shakacode/shaka/commit/#{SHA}) (modified)",
                 result(SHA, modified: true).markdown
  end

  def test_a_sha256_commit_renders_as_a_link
    sha = 'b' * 64
    assert_equal "[`bbbbbbb`](https://github.com/shakacode/shaka/commit/#{sha})", result(sha).markdown
  end

  def test_an_unknown_commit_falls_back_to_the_version_number
    assert_equal "`#{VERSION}` (commit unknown)", result(nil).markdown
    assert_equal "`#{VERSION}` (commit unknown, modified)", result(nil, modified: true).markdown
  end

  def test_refuses_values_that_could_break_the_table
    assert_raises(Shaka::Error) { result("#{SHA} | x").markdown }
    assert_raises(Shaka::Error) do
      Shaka::WorkflowVersion::Result.new(version: "1.0\n| x", commit: nil, modified: false).markdown
    end
  end
end
