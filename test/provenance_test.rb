# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/publication/provenance'

class ExecutionProvenanceTest < Minitest::Test
  PUBLIC_PROVENANCE = { 'task_source' => 'description', 'initial_prompt' => 'EXCLUDED',
                        'requested_model' => 'gpt-5.6-terra', 'requested_effort' => 'medium',
                        'recommended_model' => 'gpt-5.6-terra', 'recommended_effort' => 'medium',
                        'active_model' => 'gpt-5.6-terra', 'active_effort' => 'medium' }.freeze
  PULL = { 'base' => { 'repo' => { 'full_name' => 'shakacode/shaka' } } }.freeze
  PARTIAL_REQUESTS = [
    [nil, 'high', 'Not specified / high'],
    ['gpt-6.1-sol', nil, 'gpt-6.1-sol / Not specified'],
    [nil, 'UNKNOWN', 'Not specified / UNKNOWN'],
    ['UNKNOWN', 'UNKNOWN', 'UNKNOWN / UNKNOWN']
  ].freeze

  # The alias says who holds unfinished work, so only WIP Details Owner carries it.
  def test_leaves_the_machine_alias_and_redundant_prompt_or_observed_route_rows_out
    saved = ENV.fetch('SHAKA_MACHINE_ALIAS', nil)
    ENV['SHAKA_MACHINE_ALIAS'] = 'm5-alias'
    body = Shaka::ExecutionProvenance.new(PUBLIC_PROVENANCE).detail.fetch('body')

    refute_includes body, 'Machine alias'
    refute_includes body, 'm5-alias'
    refute_includes body, '| Initial prompt |'
    refute_includes body, '| Observed route |'
  ensure
    ENV['SHAKA_MACHINE_ALIAS'] = saved
  end

  def test_the_helper_supplies_the_workflow_version
    version = Shaka::WorkflowVersion::Result.new(version: '0.1.0.pre.1', commit: 'a' * 40, modified: false,
                                                 upstream: true)
    body = Shaka::ExecutionProvenance.new(PUBLIC_PROVENANCE, workflow_version: version).detail.fetch('body')

    assert_includes body, "| Shaka skill version | [`aaaaaaa`](https://github.com/shakacode/shaka/commit/#{'a' * 40}) |"
  end

  def test_refuses_an_agent_supplied_workflow_version
    error = assert_raises(Shaka::Error) do
      Shaka::ExecutionProvenance.new(PUBLIC_PROVENANCE.merge('workflow_version' => '0.1.0.pre.1')).detail
    end

    assert_includes error.message, 'allowlist'
  end

  def test_hides_known_absence_of_a_user_request_but_retains_it_in_metadata
    spec = PUBLIC_PROVENANCE.merge('requested_model' => nil, 'requested_effort' => nil)
    provenance = Shaka::ExecutionProvenance.new(spec)

    refute_includes provenance.detail.fetch('body'), '| User-requested model / effort |'
    assert_includes provenance.detail.fetch('body'), '| Recommended model / effort | gpt-5.6-terra / medium |'
    assert_includes provenance.detail.fetch('body'), '| Active model / effort | gpt-5.6-terra / medium |'
    assert_equal 'Not specified', provenance.entry.fetch('requested')
  end

  def test_a_partial_request_preserves_each_components_evidence
    PARTIAL_REQUESTS.each do |model, effort, expected|
      spec = PUBLIC_PROVENANCE.merge('requested_model' => model, 'requested_effort' => effort)
      provenance = Shaka::ExecutionProvenance.new(spec)
      assert_equal expected, provenance.entry.fetch('requested')
      assert_includes provenance.detail.fetch('body'), "| User-requested model / effort | #{expected} |"
    end
  end

  def test_only_explicit_null_requested_fields_record_known_absence
    %w[recommended_model recommended_effort active_model active_effort].each do |field|
      assert_raises(Shaka::Error) { Shaka::ExecutionProvenance.new(PUBLIC_PROVENANCE.merge(field => nil)).detail }
    end
    invalid = ['', false, [], 'Not specified']
    %w[requested_model requested_effort].each do |field|
      invalid.each do |value|
        assert_raises(Shaka::Error) { Shaka::ExecutionProvenance.new(PUBLIC_PROVENANCE.merge(field => value)).detail }
      end
      assert_raises(Shaka::Error) { Shaka::ExecutionProvenance.new(PUBLIC_PROVENANCE.except(field)).detail }
    end
  end

  def test_links_a_task_in_the_same_repository
    spec = PUBLIC_PROVENANCE.merge('task_source' => 'issue', 'task_number' => 778)
    body = Shaka::ExecutionProvenance.new(spec, pull: PULL).detail.fetch('body')

    assert_includes body, '| Task source | issue [#778](https://github.com/shakacode/shaka/issues/778) |'
    pull = spec.merge('task_source' => 'pull_request')
    assert_includes Shaka::ExecutionProvenance.new(pull, pull: PULL).detail.fetch('body'),
                    '| Task source | pull_request [#778](https://github.com/shakacode/shaka/pull/778) |'
    assert_includes Shaka::ExecutionProvenance.new(spec).detail.fetch('body'), '| Task source | issue #778 |'
  end

  def test_names_the_task_source_alone_without_a_task_number
    assert_includes Shaka::ExecutionProvenance.new(PUBLIC_PROVENANCE, pull: PULL).detail
                                              .fetch('body'), '| Task source | description |'
  end

  def test_refuses_a_task_number_that_cannot_name_an_issue_or_pull_request
    invalid = [['description', 778], ['issue', '778'], ['issue', 0], ['issue', 'https://example.com/778']]
    invalid.each do |source, number|
      spec = PUBLIC_PROVENANCE.merge('task_source' => source, 'task_number' => number)
      error = assert_raises(Shaka::Error) { Shaka::ExecutionProvenance.new(spec).detail }

      assert_includes error.message, 'task_number'
    end
  end

  def test_refuses_raw_prompt_content_without_echoing_it
    private_prompt = 'customer-secret-7E2A'
    error = assert_raises(Shaka::Error) do
      Shaka::ExecutionProvenance.new(PUBLIC_PROVENANCE.merge('initial_prompt' => private_prompt)).detail
    end

    assert_includes error.message, 'initial_prompt'
    refute_includes error.message, private_prompt
  end
end
