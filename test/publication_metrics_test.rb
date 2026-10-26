# frozen_string_literal: true

require_relative 'publication_test'

# The outer disclosure must preserve accounting and recoverable publication records.
class PublicationMetricsTest < Minitest::Test
  def test_cost_remains_visible_with_partial_data_and_unknown_labels_preserved
    rendered = render(usd: '$1.25 (partial)')
    visible, metrics = rendered.split("<details>\n<summary>Details</summary>", 2)
    assert_includes visible, '**Estimated token costs:** $1.25+'
    assert_includes metrics, '<summary>Usage and cost · $1.25+ estimated</summary>'
    assert_includes metrics, 'some usage not reported, so the amount is a minimum'
    assert_includes metrics, 'Native usage is PARTIAL.'
    assert_includes metrics, '| Active model / effort | gpt-5.6-terra / medium |'
    assert_includes metrics, 'UNKNOWN'
  end

  def test_all_metadata_is_nested_while_change_specific_evidence_is_a_peer
    rendered = render(usd: '$0.00')
    hierarchy = disclosure_hierarchy(rendered)
    assert_includes hierarchy, [1, 'Capture limits']
    assert_includes hierarchy, [0, 'Evidence and limitations']
    assert_includes hierarchy, [0, 'Details']
    ['Execution details', 'Skills used', 'Usage and cost', 'Shaka settings used'].each do |summary|
      assert hierarchy.any? { |depth, title| depth == 1 && title.start_with?(summary) }, summary
    end
    assert_includes rendered.split('<summary>Details</summary>').first, '**Estimated token costs:** $0.00'
  end

  def test_metrics_prioritize_usage_and_time_before_configuration_and_history
    rendered = render(usd: '$1.25')
    usage = rendered.index('<summary>Usage and cost')
    execution = rendered.index('<summary>Execution details')
    settings = rendered.index('<summary>Shaka settings used')
    skills = rendered.index('<summary>Skills used')
    assert_operator usage, :<, execution
    assert_operator execution, :<, settings
    assert_operator settings, :<, skills
  end

  def test_material_gaps_stay_visible_while_supporting_proof_and_task_history_fold
    spec = content(usd: 'UNKNOWN')
    spec['verification'] = VERIFICATION.merge('merge_limitations' => 'Live migration needs maintainer approval.')
    spec['task_history'] = 'The maintainer requested this change.'
    rendered = Shaka::Publication.description(spec)
    visible = rendered.split('<summary>Evidence and limitations</summary>').first
    assert_includes visible, '**Not verified:** Live migration needs maintainer approval.'
    refute_includes visible, VERIFICATION['checks'].first
    hierarchy = disclosure_hierarchy(rendered)
    assert_includes hierarchy, [1, 'Task history']
  end

  def test_republication_carries_usage_from_inside_the_metrics_group
    first = render(usd: '$1.25')
    fresh = content(usd: '$0.75')
    fresh['usage']['records'].first.merge!('responses' => ['second'], 'sources' => ['second'])
    carried, = Shaka::UsageRecords.carry(fresh, "<!-- shaka:begin -->\n#{first}\n<!-- shaka:end -->")
    rendered = Shaka::Publication.description(carried)
    assert_includes rendered, '**Estimated token costs:** $2.00'
    assert_equal 2, Shaka::UsageRecords.text_records(rendered).size
  end

  def test_scope_exclusions_are_optional_and_blank_ones_are_omitted
    [INTENT.except('leaves_out'), INTENT.merge('leaves_out' => ' ')].each do |intent|
      refute_includes Shaka::Publication.description(content(usd: 'UNKNOWN').merge('intent' => intent)),
                      '**Leaves out:**'
    end
  end

  # Readers saw three lines of counts before the reason for the change, so the counts close Intent.
  def test_diff_size_comes_from_the_live_pull_request_and_closes_intent
    pull = { 'changed_files' => 2, 'additions' => 5, 'deletions' => 1,
             'shaka_changed_files' => [{ 'filename' => 'lib/a.rb' }, { 'filename' => 'test/a_test.rb' }] }
    rendered = Shaka::IntentVerification.render({ 'intent' => INTENT, 'verification' => VERIFICATION }, nil, nil, pull)

    assert rendered.first.end_with?("**Scope:** #{INTENT['scope']} (2 files, +5 / −1 lines)\n\n" \
                                    "<details>\n<summary>Files: Code 1 · Tests 1</summary>\n\n" \
                                    "**Code:**\n\n- `lib/a.rb`\n\n**Tests:**\n\n- `test/a_test.rb`\n\n</details>")
    refute_includes render(usd: 'UNKNOWN'), 'lines)'
  end

  private

  def content(usd:)
    fixture = PublicationRegressionTest
    record = USAGE_RECORD.merge('columns' => [fixture::USAGE_COLUMN.merge('usd' => usd)])
    { 'identity' => fixture::IDENTITY, 'summary' => 'Review the change.', 'intent' => INTENT,
      'verification' => VERIFICATION, 'deployment' => 'none', 'steps_besides_merging' => 'none',
      'provenance' => PUBLIC_PROVENANCE, 'usage' => { 'note' => 'Native usage is PARTIAL.', 'records' => [record] },
      'details' => [{ 'summary' => 'Capture limits', 'body' => 'Change-specific capture evidence.' }] }
  end

  def render(**) = Shaka::Publication.description(content(**))

  def disclosure_hierarchy(rendered)
    depth = 0
    hierarchy = rendered.scan(%r{(<details>|</details>|<summary>(.*?)</summary>)}).filter_map do |token, summary|
      depth += 1 if token == '<details>'
      depth -= 1 if token == '</details>'
      [depth - 1, summary] if summary
    end
    assert_equal 0, depth, 'all nested disclosures close'
    hierarchy
  end
end
