# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/provenance'

class ExecutionProvenanceTest < Minitest::Test
  PUBLIC_PROVENANCE = { 'task_source' => 'description', 'initial_prompt' => 'EXCLUDED',
                        'workflow_version' => 'v1.2.3',
                        'requested_model' => 'gpt-5.6-terra', 'requested_effort' => 'medium',
                        'recommended_model' => 'gpt-5.6-terra', 'recommended_effort' => 'medium',
                        'active_model' => 'gpt-5.6-terra', 'active_effort' => 'medium' }.freeze

  def test_renders_public_machine_alias_without_redundant_prompt_or_observed_route_rows
    body = Shaka::ExecutionProvenance.new(
      PUBLIC_PROVENANCE, environment: { 'SHAKA_MACHINE_ALIAS' => 'm5' }
    ).detail.fetch('body')

    assert_includes body, '| Machine alias | m5 |'
    refute_includes body, '| Initial prompt |'
    refute_includes body, '| Observed route |'
  end

  def test_uses_unknown_when_machine_alias_is_unavailable
    body = Shaka::ExecutionProvenance.new(PUBLIC_PROVENANCE, environment: {}).detail.fetch('body')

    assert_includes body, '| Machine alias | UNKNOWN |'
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
