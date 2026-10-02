# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/publication/provenance'

class ExecutionProvenanceTest < Minitest::Test
  PUBLIC_PROVENANCE = { 'task_source' => 'description', 'initial_prompt' => 'EXCLUDED',
                        'requested_model' => 'gpt-5.6-terra', 'requested_effort' => 'medium',
                        'recommended_model' => 'gpt-5.6-terra', 'recommended_effort' => 'medium',
                        'active_model' => 'gpt-5.6-terra', 'active_effort' => 'medium' }.freeze
  PARTIAL_REQUESTS = [
    [nil, 'high', 'Not specified / high'],
    ['gpt-6.1-sol', nil, 'gpt-6.1-sol / Not specified'],
    [nil, 'UNKNOWN', 'Not specified / UNKNOWN'],
    ['UNKNOWN', 'UNKNOWN', 'UNKNOWN / UNKNOWN']
  ].freeze

  def test_renders_public_machine_alias_without_redundant_prompt_or_observed_route_rows
    body = Shaka::ExecutionProvenance.new(
      PUBLIC_PROVENANCE, environment: { 'SHAKA_MACHINE_ALIAS' => 'm5' }
    ).detail.fetch('body')

    assert_includes body, '| Machine alias | m5 |'
    refute_includes body, '| Initial prompt |'
    refute_includes body, '| Observed route |'
  end

  def test_the_helper_supplies_the_workflow_version
    version = Shaka::WorkflowVersion::Result.new(version: '0.1.0.pre.1', commit: 'a' * 40, modified: false,
                                                 upstream: true)
    body = Shaka::ExecutionProvenance.new(PUBLIC_PROVENANCE, environment: {}, workflow_version: version)
                                     .detail.fetch('body')

    assert_includes body, "| Workflow version | [`aaaaaaa`](https://github.com/shakacode/shaka/commit/#{'a' * 40}) |"
  end

  def test_refuses_an_agent_supplied_workflow_version
    error = assert_raises(Shaka::Error) do
      Shaka::ExecutionProvenance.new(PUBLIC_PROVENANCE.merge('workflow_version' => '0.1.0.pre.1')).detail
    end

    assert_includes error.message, 'allowlist'
  end

  def test_uses_unknown_when_machine_alias_is_unavailable
    body = Shaka::ExecutionProvenance.new(PUBLIC_PROVENANCE, environment: {}).detail.fetch('body')

    assert_includes body, '| Machine alias | UNKNOWN |'
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

  def test_ignores_the_retired_coordination_machine_variable
    body = Shaka::ExecutionProvenance.new(
      PUBLIC_PROVENANCE, environment: { 'AGENT_COORD_MACHINE_ID' => 'm5' }
    ).detail.fetch('body')

    assert_includes body, '| Machine alias | UNKNOWN |'
  end

  def test_never_falls_back_to_a_host_name
    body = Shaka::ExecutionProvenance.new(
      PUBLIC_PROVENANCE,
      environment: { 'HOST' => 'developer-laptop-m5-max', 'HOSTNAME' => 'developer-laptop-m5-max' }
    ).detail.fetch('body')

    assert_includes body, '| Machine alias | UNKNOWN |'
    refute_includes body, 'developer-laptop-m5-max'
  end

  def test_refuses_an_unsafe_machine_alias_without_echoing_it
    private_alias = 'customer machine'
    error = assert_raises(Shaka::Error) do
      Shaka::ExecutionProvenance.new(
        PUBLIC_PROVENANCE, environment: { 'SHAKA_MACHINE_ALIAS' => private_alias }
      ).detail
    end

    assert_includes error.message, 'machine alias'
    refute_includes error.message, private_alias
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
