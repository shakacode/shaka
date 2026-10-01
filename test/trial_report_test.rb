# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/trial/command'
require 'tempfile'

class TrialReportTest < Minitest::Test
  URL = 'https://github.com/shakacode/shaka/pull/359'
  HEAD = 'a' * 40

  def setup
    @calls = []
    @labels = []
    @private = false
    @body = "Workflow version: https://github.com/shakacode/shaka/commit/#{HEAD}"
    build_client
  end

  def build_client
    owner = self
    @github = Object.new
    @github.define_singleton_method(:api) { |*args, **kwargs| owner.api(*args, **kwargs) }
    @github.define_singleton_method(:reply) do |**kwargs|
      owner.calls << kwargs
      { 'body' => kwargs[:body] }
    end
  end

  attr_reader :calls

  def api(path, **options)
    unless options.empty?
      @labels << options.fetch(:fields)
      assert_equal Array, options.fetch(:expected)
      return []
    end
    return { 'sha' => HEAD } if path.include?('/commits/')
    return { 'state' => 'open', 'base' => { 'repo' => { 'full_name' => 'shakacode/shaka', 'private' => false } } } if
      path == 'repos/shakacode/shaka/pulls/359'
    return { 'private' => @private, 'visibility' => @private ? 'private' : 'public' } if path == 'repos/team/project'

    { 'body' => @body }
  end

  def test_reports_a_public_result_with_exact_revision_and_applies_evaluation_label
    result = report('result_url' => 'https://github.com/team/project/pull/7')
    assert_includes result['body'], HEAD
    assert_includes result['body'], 'team/project/pull/7'
    assert_includes result['body'], 'keep'
    assert_equal [{ labels: ['eval-required'] }], @labels
    assert_match(/field-trial-example-/, calls.last[:key])
  end

  def test_refuses_a_private_result_before_any_comment_is_written
    @private = true
    assert_raises(Shaka::Error) { report('result_url' => 'https://github.com/team/project/pull/7') }
    assert_empty calls
  end

  def test_refuses_result_without_matching_workflow_provenance
    @body = 'No evidence this version was used'
    assert_raises(Shaka::Error) { report('result_url' => 'https://github.com/team/project/pull/7') }
    assert_empty calls
  end

  def test_supports_a_public_safe_summary_without_a_private_link
    result = report('private_result' => true)
    assert_includes result['body'], 'Private result; link withheld'
    assert_includes result['body'], 'Reported by the tester'
  end

  def test_requires_a_result_or_explicit_private_result
    assert_raises(Shaka::Error) { report }
    assert_empty calls
  end

  def test_refuses_private_links_embedded_in_the_summary
    @private = true
    assert_raises(Shaka::Error) do
      report('private_result' => true, 'summary' => 'See HTTPS://GitHub.com/team/project/pull/7')
    end
    assert_empty calls
    assert_empty @labels
  end

  def test_cli_publishes_a_report_from_json
    content = { 'id' => 'cli-example', 'candidate_head' => HEAD, 'verdict' => 'revise',
                'summary' => 'Useful with one correction.', 'result_url' => 'https://github.com/team/project/pull/7' }
    Tempfile.create(['trial-report', '.json']) do |file|
      file.write(JSON.generate(content))
      file.flush
      output = cli(file.path)
      assert_includes JSON.parse(output)['body'], 'revise'
    end
  end

  private

  def cli(path)
    original = Shaka::GitHub.method(:new)
    client = @github
    Shaka::GitHub.define_singleton_method(:new) { |*| client }
    capture_io do
      assert_equal 0, Shaka::Trial::Command.run(['report', URL, '--content-file', path])
    end.first
  ensure
    Shaka::GitHub.define_singleton_method(:new, original)
  end

  def report(extra = {})
    content = { 'id' => 'example', 'candidate_head' => HEAD, 'verdict' => 'keep',
                'summary' => 'Useful; needed one correction.' }.merge(extra)
    Shaka::Trial::Report.new(URL, content, github: @github, results: @github).run
  end
end
