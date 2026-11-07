# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'open3'
require 'tmpdir'

# Proves the `pr` command itself falls back to REST when GitHub refuses GraphQL.
class CliPrRestFallbackTest < Minitest::Test
  COMMAND = SHAKA_COMMAND
  # Refuses GraphQL the way a Claude Code cloud session does and answers the REST reads `pr` makes.
  FAKE_GH = <<~RUBY
    #!/usr/bin/env ruby
    require 'json'
    head = 'a' * 40
    args = ARGV.join(' ')
    case args
    when /\\Aapi graphql/
      warn 'gh: GitHub GraphQL is not available from Claude Code sessions. (HTTP 403)'; exit 1
    when %r{\\Aapi repos/owner/repo/pulls/1 }
      puts JSON.generate('number' => 1, 'state' => 'open', 'head' => { 'sha' => head }, 'base' => { 'ref' => 'main' })
    when %r{\\Aapi repos/owner/repo/commits/a+/check-runs}
      run = { 'name' => 'validate', 'status' => 'completed', 'conclusion' => 'success', 'head_sha' => head }
      puts JSON.generate('total_count' => 1, 'check_runs' => [run])
    when %r{\\Aapi repos/owner/repo/commits/a+/status}
      puts JSON.generate('sha' => head, 'total_count' => 0, 'statuses' => [])
    when %r{\\Aapi repos/owner/repo/branches/main} then puts JSON.generate('protected' => false)
    when %r{\\Aapi repos/owner/repo/rules/branches/main}
      checks = [{ 'context' => 'validate' }]
      puts JSON.generate([{ 'type' => 'required_status_checks', 'parameters' => { 'required_status_checks' => checks } }])
    else warn "unexpected gh \#{args}"; exit 2
    end
  RUBY

  def test_pr_reads_over_rest_when_github_refuses_graphql
    output, error, status = run_pr

    assert_predicate status, :success?, error
    result = JSON.parse(output)
    assert_equal %w[rest github], result.values_at('readOver', 'requiredChecksSource')
    assert_equal(['validate'], result['requiredChecks'].map { |check| check['name'] })
    assert_includes result['unknownFields'], 'reviewDecision'
  end

  private

  def run_pr
    Dir.mktmpdir do |bin|
      File.write(File.join(bin, 'gh'), FAKE_GH)
      File.chmod(0o755, File.join(bin, 'gh'))
      Open3.capture3({ 'PATH' => "#{bin}:#{ENV.fetch('PATH')}" }, *COMMAND, 'pr', 'owner/repo', '1')
    end
  end
end
