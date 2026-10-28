# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/workflow_pins'

class EvaluationWorkflowPinsTest < Minitest::Test
  def read(text) = Shaka::Evaluation::WorkflowPins.new('ci.yml').read(text)
  def step(value) = "jobs:\n  build:\n    steps:\n      - uses: #{value}\n"

  def test_different_locations_keep_different_revisions_of_the_same_action
    text = step("owner/action@#{'a' * 40}") + "      - uses: owner/action@#{'b' * 40}\n"
    assert_equal ['a' * 40, 'b' * 40].sort, read(text).values.sort
  end

  def test_reusable_workflow_call_has_its_own_location
    text = "jobs:\n  build:\n    uses: owner/repo/.github/workflows/build.yml@#{'a' * 40}\n"
    assert_equal({ 'ci.yml#jobs/build/uses:owner/repo/.github/workflows/build.yml' => 'a' * 40 }, read(text))
  end

  def test_mutable_local_container_expression_and_wrong_types_remain_unknown
    ['owner/action@v1', './local', 'docker://image@sha256:abc', '${{ matrix.action }}',
     'null', '[]', '{}', "owner/action/../other@#{'a' * 40}"].each do |value|
      assert_equal 'UNKNOWN', read(step(value))
    end
  end

  def test_duplicate_keys_and_aliases_cannot_hide_a_mutable_reference
    [step('owner/action@v1') + "        uses: owner/action@#{'a' * 40}\n",
     "jobs: {}\njobs: {}\n", "jobs:\n  one: &job {}\n  two: *job\n",
     "jobs: {}\n---\njobs: {}\n", "jobs: [\n", "jobs: !ruby/object:Unsafe {}\n",
     "? [complex, key]\n: value\njobs: {}\n"].each do |text|
      assert_equal 'UNKNOWN', read(text)
    end
  end

  def test_unsupported_uses_locations_remain_unknown
    text = "jobs:\n  build:\n    steps:\n      - parallel:\n          - uses: owner/action@#{'a' * 40}\n"
    assert_equal 'UNKNOWN', read(text)
    assert_equal 'UNKNOWN', read("jobs: {}\nenv:\n  uses: owner/action@#{'a' * 40}\n")
  end

  def test_command_text_is_not_a_reference
    assert_empty read("jobs:\n  build:\n    steps:\n      - run: 'echo uses: owner/action@v1'\n")
  end

  def test_excessive_depth_or_node_count_remains_unknown
    assert_equal 'UNKNOWN', read("jobs: {}\nother: #{'[' * 42}0#{']' * 42}\n")
    rows = (1..10_001).map { "  k#{it}: value\n" }.join
    text = "jobs: {}\nenv:\n#{rows}"
    assert_equal 'UNKNOWN', read(text)
  end
end
