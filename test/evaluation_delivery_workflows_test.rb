# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/delivery_workflows'
require_relative '../eval/lib/shaka/evaluation/run_record'
require_relative 'support/evaluation_workflow_fixture'

class EvaluationDeliveryWorkflowsTest < Minitest::Test
  include EvaluationWorkflowFixture

  def test_native_workflow_pins_bind_the_immutable_head_and_blobs
    response = workflow
    result = capture_workflows(response)
    assert_equal HEAD, result.fetch('head')
    assert_equal response.dig('data', 'repository', 'object', 'oid'), result.fetch('tree_oid')
    assert_equal({ '.github/workflows/ci.yml#jobs/build/steps/0/uses:actions/checkout' => 'b' * 40 },
                 result.fetch('pinned_actions'))
    assert_equal response.dig('data', 'repository', 'object', 'entries', 0, 'oid'),
                 result.dig('workflow_blobs', '.github/workflows/ci.yml')
    assert_kind_of Numeric, result.fetch('observed_at')
  end

  def test_query_is_read_only_and_uses_the_full_head_as_a_variable
    capture_workflows
    request = JSON.parse(requests.first.fetch('input'))
    assert request.fetch('query').start_with?('query')
    assert_equal "#{HEAD}:.github/workflows", request.dig('variables', 'expression')
    refute_includes request.fetch('query'), HEAD
  end

  def test_declared_pins_and_unknown_fit_the_existing_record_field
    record = Shaka::Evaluation::RunRecord
    rule = JSON.parse(File.read(record::PATH)).dig('$defs', 'fingerprint', 'properties', 'pinned_actions')
    assert_empty record::SCHEMA.errors(capture_workflows.fetch('pinned_actions'), rule)
    assert_empty record::SCHEMA.errors('UNKNOWN', rule)
  end

  def test_empty_native_tree_and_workflow_without_actions_have_no_declared_pins
    assert_empty capture_workflows(workflow_set({})).fetch('pinned_actions')
    plain = workflow("jobs:\n  build:\n    steps:\n      - run: echo hello\n")
    assert_empty capture_workflows(plain).fetch('pinned_actions')
  end

  def test_incomplete_or_changed_tree_inventory_is_unavailable
    [->(tree) { tree['entries'] = [] }, ->(tree) { tree['oid'] = 'c' * 40 }].each do |mutate|
      response = workflow
      mutate.call(response.dig('data', 'repository', 'object'))
      assert_raises(IOError) { capture_workflows(response) }
    end
  end

  def test_duplicate_or_invalid_tree_entries_are_unavailable
    [->(tree) { tree['entries'] *= 2 }, ->(tree) { tree['entries'][0]['mode'] = 0 }].each do |mutate|
      response = workflow
      mutate.call(response.dig('data', 'repository', 'object'))
      assert_raises(IOError) { capture_workflows(response) }
    end
  end

  def test_incomplete_or_changed_blob_content_is_unavailable
    [{ 'isTruncated' => true }, { 'isBinary' => true }, { 'byteSize' => 0 }, { 'oid' => 'c' * 40 },
     { 'text' => nil }].each do |change|
      response = workflow
      response.dig('data', 'repository', 'object', 'entries', 0, 'object').merge!(change)
      assert_raises(IOError) { capture_workflows(response) }
    end
  end

  def test_text_with_updated_size_but_stale_git_identity_is_unavailable
    response = workflow
    blob = response.dig('data', 'repository', 'object', 'entries', 0, 'object')
    blob['text'] += '# altered'
    blob['byteSize'] = blob['text'].bytesize
    assert_raises(IOError) { capture_workflows(response) }
  end

  def test_unreadable_or_wrong_repository_is_unavailable
    [nil, { 'errors' => [] }, { 'data' => { 'repository' => nil } }].each do |response|
      assert_raises(IOError) { capture_workflows(response) }
    end
    response = workflow
    response['data']['repository']['nameWithOwner'] = 'other/repository'
    assert_raises(IOError) { capture_workflows(response) }
  end

  def test_one_mutable_reference_makes_the_complete_field_unknown_without_retaining_text
    response = workflow_set('ci.yml' => "jobs:\n  x:\n    uses: owner/repo/.github/workflows/ci.yml@#{'b' * 40}\n",
                            'other.yaml' => "jobs:\n  x:\n    steps:\n      - uses: owner/action@v1\n",
                            'README' => 'private source text')
    result = capture_workflows(response)
    assert_equal 'UNKNOWN', result['pinned_actions']
    assert_equal 2, result['workflow_blobs'].size
    refute_includes JSON.generate(result), 'private source text'
    refute_includes JSON.generate(result), 'jobs:'
  end
end
