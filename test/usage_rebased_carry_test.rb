# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'publication_test'
require 'json'

# A PR rebased many times must stay under GitHub's body limit without losing measured usage (#878).
class UsageRebasedCarryTest < Minitest::Test
  COLUMN = PublicationUsageTableTest::COLUMN
  REVIEW = PublicationUsageTableTest::REVIEW
  NOTE = "Rate card: installed Shaka.\n\nAnthropic API list prices, verified 2026-09-23."
  OTHER_NOTE = "Rate card: candidate checkout.\n\nAnthropic API list prices, verified 2026-09-23."
  REPO = { 'repo' => { 'full_name' => 'shakacode/shaka' } }.freeze

  def record(column = COLUMN, note: NOTE, **fields)
    USAGE_RECORD.merge('columns' => [column], 'note' => note).merge(fields.transform_keys(&:to_s))
  end

  def implementation(commit, responses, **fields) = record(commits: [commit * 40], responses:, **fields)

  def review(commit, response) = record(REVIEW, contribution: 'review', commits: [commit * 40], responses: [response])

  # Publishes the way `description` does: carry from the live body, then render the whole description.
  def publish(body, records)
    content, stats = Shaka::UsageRecords.carry_from({ 'usage' => { 'note' => 'n', 'records' => records } },
                                                    'body' => body, 'head' => REPO, 'base' => REPO)
    rendered = PublicationUsageTableTest.new('render').render(usage: content['usage'])
    ["#{Shaka::Publishing::OPEN_MARK}\n#{rendered}\n#{Shaka::Publishing::CLOSE_MARK}", stats]
  end

  def identities(body) = Shaka::UsageRecords.text_records(body)

  def reports(body, contribution) = identities(body).select { |fields| fields['contribution'] == contribution }

  # Each head adds one review and an implementation report counting every response so far.
  def rebased_three_times
    body, = publish('', [implementation('a', %w[c1]), review('a', 'r1')])
    body, = publish(body, [implementation('b', %w[c1 c2]), review('b', 'r2')])
    publish(body, [implementation('c', %w[c1 c2 c3]), review('c', 'r3')])
  end

  # A body published before notes were shared, with every report holding its note in full.
  def unshared(entries)
    blocks = entries.map do |entry|
      hidden = "<!-- usage-columns #{JSON.generate(entry['columns'])} -->\n#{Shaka::UsagePricing.hidden(entry['note'])}"
      identity = Shaka::UsageRecordCarry.identity(entry.except('columns', 'note'))
      "#{Shaka::UsageRecords.begin_mark(identity)}\n#{hidden}\n#{Shaka::UsageRecords::END_MARK}"
    end
    "#{Shaka::Publishing::OPEN_MARK}\n#{blocks.join("\n\n")}\n#{Shaka::Publishing::CLOSE_MARK}"
  end

  # Break: PR 837 kept every cumulative implementation report, one per rebased head, because a
  # replacement had to name every commit the old report named.
  def test_a_report_from_a_rebased_head_replaces_the_reports_it_covers
    body, stats = rebased_three_times

    work = reports(body, 'implementation').map { |fields| fields.values_at('responses', 'commits') }
    assert_equal [[%w[c1 c2 c3], %w[c b a].map { |commit| commit * 40 }]], work
    assert_equal 3, reports(body, 'review').size
    assert_equal({ 'retained' => 2, 'replaced' => 1, 'dropped' => 0 }, stats)
  end

  # Break: republishing the same report found its carried copy naming more commits and kept both.
  def test_republishing_the_same_report_keeps_one_copy
    body, = publish('', [implementation('a', %w[c1])])
    body, = publish(body, [implementation('b', %w[c1 c2])])
    body, stats = publish(body, [implementation('b', %w[c1 c2])])

    assert_equal 1, identities(body).size
    assert_equal({ 'retained' => 0, 'replaced' => 1, 'dropped' => 0 }, stats)
  end

  # Break: a newer report missing one earlier response would have erased that response's usage.
  def test_a_report_missing_an_earlier_response_keeps_the_earlier_report
    body, = publish('', [implementation('a', %w[c1 c2])])
    body, = publish(body, [implementation('b', %w[c2 c3])])

    assert_equal([['a' * 40], ['b' * 40]], identities(body).map { |fields| fields['commits'] })
  end

  def test_each_note_is_written_once_in_full
    body, = publish('', [review('a', 'r1'), review('b', 'r2'), record(note: OTHER_NOTE)])

    assert_equal 2, body.scan("<!-- usage-note\n").size
    assert_equal 1, body.scan('<!-- usage-note-ref').size
    pricing = body[%r{<summary>How each report was measured and priced</summary>.*?</details>}m]
    assert_includes pricing, "**claude‑opus‑5‑5 review ×2**\n\n#{NOTE}"
  end

  # Break: replacing the report that held a note in full left the reports pointing to it with none.
  def test_a_carried_report_keeps_its_note_after_the_report_holding_it_is_replaced
    body, = publish('', [implementation('a', %w[c1]), review('a', 'r1')])
    assert_includes body[/<!-- shaka:usage \{[^\n]*"r1".*?<!-- shaka:usage:end -->/m], '<!-- usage-note-ref'

    body, = publish(body, [implementation('b', %w[c1 c2], note: OTHER_NOTE)])

    review_block = body[/<!-- shaka:usage \{[^\n]*"r1".*?<!-- shaka:usage:end -->/m]
    assert_equal NOTE, Shaka::UsagePricing.from_block(review_block)
    refute_includes body, '_No note was recorded'
  end

  # Break: a body published before notes were shared, such as PR 837's, would lose its notes.
  def test_a_body_with_a_full_note_in_every_report_is_read_and_shared
    body, stats = publish(unshared([review('a', 'r1'), review('b', 'r2')]), [review('c', 'r3')])

    assert_equal 2, stats['retained']
    assert_equal 1, body.scan("<!-- usage-note\n").size
    assert_equal 2, body.scan('<!-- usage-note-ref').size
  end
end
