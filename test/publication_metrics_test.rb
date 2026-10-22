# frozen_string_literal: true

require_relative 'publication_test'

# The outer disclosure must preserve accounting and recoverable publication records.
class PublicationMetricsTest < Minitest::Test
  def test_cost_remains_visible_with_partial_data_and_unknown_labels_preserved
    rendered = render(usd: '$1.25 (partial)')
    visible, metrics = rendered.split("<details>\n<summary>Shaka metrics</summary>", 2)
    assert_includes visible, '**Estimated cost:** $1.25+'
    assert_includes metrics, '<summary>Usage and cost · $1.25+ estimated</summary>'
    assert_includes metrics, 'some usage not reported, so the amount is a minimum'
    assert_includes metrics, 'Native usage is PARTIAL.'
    assert_includes metrics, '| Active model / effort | gpt-5.6-terra / medium |'
    assert_includes metrics, 'UNKNOWN'
  end

  def test_all_metadata_is_nested_while_change_specific_evidence_is_a_peer
    rendered = render(usd: '$0.00')
    hierarchy = disclosure_hierarchy(rendered)
    assert_includes hierarchy, [0, 'Capture limits']
    assert_includes hierarchy, [0, 'Shaka metrics']
    ['Execution details', 'Skills used', 'Usage and cost', 'Shaka settings used'].each do |summary|
      assert hierarchy.any? { |depth, title| depth == 1 && title.start_with?(summary) }, summary
    end
    assert_includes rendered.split('<summary>Shaka metrics</summary>').first, '**Estimated cost:** $0.00'
  end

  def test_republication_carries_usage_from_inside_the_metrics_group
    first = render(usd: '$1.25')
    fresh = content(usd: '$0.75')
    fresh['usage']['records'].first.merge!('responses' => ['second'], 'sources' => ['second'])
    carried, = Shaka::UsageRecords.carry(fresh, "<!-- shaka:begin -->\n#{first}\n<!-- shaka:end -->")
    rendered = Shaka::Publication.description(carried)
    assert_includes rendered, '**Estimated cost:** $2.00'
    assert_equal 2, Shaka::UsageRecords.text_records(rendered).size
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
