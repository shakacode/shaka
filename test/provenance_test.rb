# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/provenance'

class ExecutionProvenanceTest < Minitest::Test
  PUBLIC_PROVENANCE = { 'task_source' => 'description', 'initial_prompt' => 'EXCLUDED',
                        'workflow_version' => 'v1.2.3',
                        'requested_model' => 'gpt-5.6-terra', 'requested_effort' => 'medium',
                        'recommended_model' => 'gpt-5.6-terra', 'recommended_effort' => 'medium',
                        'active_model' => 'gpt-5.6-terra', 'active_effort' => 'medium' }.freeze

  def test_refuses_raw_prompt_content_without_echoing_it
    private_prompt = 'customer-secret-7E2A'
    error = assert_raises(Shaka::Error) do
      Shaka::ExecutionProvenance.new(PUBLIC_PROVENANCE.merge('initial_prompt' => private_prompt)).detail
    end

    assert_includes error.message, 'initial_prompt'
    refute_includes error.message, private_prompt
  end
end
