# frozen_string_literal: true

require_relative 'test_helper'
require 'yaml'

class CodeqlWorkflowTest < Minitest::Test
  PIN = /\A[0-9a-f]{40}\z/

  def setup
    @path = File.expand_path('../.github/workflows/codeql.yml', __dir__)
    @workflow = YAML.load_file(@path)
    @validate = YAML.load_file(File.expand_path('../.github/workflows/validate.yml', __dir__))
  end

  def test_analyzes_ruby_on_pull_request_and_default_branch_push
    on = @workflow['on'] || @workflow[true]

    assert_includes on.keys, 'pull_request'
    assert_equal ['main'], on.dig('push', 'branches')
    assert_equal 'ruby', matrix.fetch('language')
    assert_equal 'none', matrix.fetch('build-mode')
  end

  def test_pins_actions_with_full_shas_like_validate
    checkout = uses('actions/checkout')
    validate_checkout = @validate.dig('jobs', 'validate', 'steps').find do |step|
      step['uses'].to_s.start_with?('actions/checkout@')
    end.fetch('uses')

    source = File.read(@path)

    assert_equal validate_checkout, checkout
    assert_match PIN, pin('github/codeql-action/init')
    assert_equal pin('github/codeql-action/init'), pin('github/codeql-action/analyze')
    assert_match(%r{github/codeql-action/init@[0-9a-f]{40} # v}, source)
    assert_match(%r{github/codeql-action/analyze@[0-9a-f]{40} # v}, source)
  end

  def test_declares_code_scanning_permissions
    permissions = @workflow.dig('jobs', 'analyze', 'permissions')

    assert_equal 'write', permissions.fetch('security-events')
    assert_equal 'read', permissions.fetch('contents')
    refute_includes permissions.keys, 'packages'
  end

  def test_cancels_only_obsolete_pull_request_analysis
    concurrency = @workflow.fetch('concurrency')
    expected_group = '${{ github.workflow }}-${{ github.event.pull_request.number || github.run_id }}'

    assert_equal expected_group, concurrency.fetch('group')
    assert_equal "${{ github.event_name == 'pull_request' }}", concurrency.fetch('cancel-in-progress')
  end

  def test_reports_on_every_pull_request_and_merge_group_so_main_can_require_it
    on = @workflow['on'] || @workflow[true]

    assert on.key?('merge_group')
    refute on['pull_request'].to_h.key?('paths-ignore')
    refute on['push'].to_h.key?('paths-ignore')
  end

  def test_analyzes_every_change_including_documentation
    steps = @workflow.dig('jobs', 'analyze', 'steps')

    refute(steps.any? { |step| step['id'] == 'changes' })
    assert(steps.none? { |step| step.key?('if') })
  end

  private

  def matrix
    @workflow.dig('jobs', 'analyze', 'strategy', 'matrix', 'include').fetch(0)
  end

  def uses(name)
    step = @workflow.dig('jobs', 'analyze', 'steps').find { |item| item['uses'].to_s.start_with?("#{name}@") }
    flunk "missing #{name} step" unless step

    step.fetch('uses')
  end

  def pin(name)
    uses(name).split('@', 2).last.split(' #', 2).first
  end
end
