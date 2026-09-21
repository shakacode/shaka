# frozen_string_literal: true

require_relative 'test_helper'
require 'yaml'

class ValidateWorkflowTest < Minitest::Test
  def setup
    @workflow = YAML.load_file(File.expand_path('../.github/workflows/validate.yml', __dir__))
  end

  def test_runs_required_validation_for_pull_requests_merge_groups_and_main
    on = @workflow['on'] || @workflow[true]

    assert_includes on.keys, 'pull_request'
    assert_includes on.keys, 'merge_group'
    assert_equal ['main'], on.dig('push', 'branches')
  end

  def test_cancels_only_obsolete_pull_request_validation
    concurrency = @workflow.fetch('concurrency')
    expected_group = '${{ github.workflow }}-${{ github.event.pull_request.number || github.run_id }}'

    assert_equal expected_group, concurrency.fetch('group')
    assert_equal "${{ github.event_name == 'pull_request' }}", concurrency.fetch('cancel-in-progress')
  end
end
