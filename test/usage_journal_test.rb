# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/usage/journal'
require 'shaka/publication/managed_region'

module UsageJournalFixture
  def reader(github) = Shaka::UsageJournal.new(github, identity: 'id')
  def notes(journal) = journal.collect['records'].map { |entry| entry['note'] }.uniq

  def record(response, model: 'gpt-6.1-sol', effort: 'medium', commits: ['a' * 40])
    USAGE_RECORD.merge('host' => 'codex', 'responses' => [response], 'commits' => commits, 'note' => 'Native sample.',
                       'columns' => [{ 'label' => 'implementation', 'provider' => 'openai', 'model' => model,
                                       'routed' => 'UNKNOWN', 'effort' => effort, 'credits' => '1 credits',
                                       'usd' => '$0.10', 'input' => '100', 'cached_input' => '40', 'output' => '20',
                                       'reasoning_output' => '5', 'cache_writes' => '0' }])
  end
end

class UsageJournalTest < Minitest::Test
  include UsageJournalFixture

  class GitHub
    attr_reader :repository, :number, :comments, :writes
    attr_accessor :stale, :fail_after, :author

    def initialize
      @repository = 'owner/repo'
      @number = 12
      @comments = []
      @writes = []
      @author = 'writer'
    end

    def api_list(_path) = @stale ? [] : @comments.dup
    def verify_rendering(_body) = ''

    def api(path, method: 'GET', fields: {})
      return permission(path) if path.include?('/permission')
      return { 'head' => { 'sha' => 'a' * 40 } } if path.include?('/pulls/')

      raise 'usage must append; never PATCH a shared body' unless method == 'POST'

      raise Shaka::Error, 'temporary failure' if @fail_after && @writes.size == @fail_after

      @writes << [path, fields]
      comment = fields.transform_keys(&:to_s).merge('id' => @comments.size + 1, 'html_url' => 'https://github.com/owner/repo/pull/12#issuecomment-1',
                                                    'user' => { 'login' => author })
      @comments << comment
      comment
    end

    def permission(path)
      login = path.split('/')[-2]
      raise Shaka::Error.new('gh api failed.', http_status: 404) if login == 'gone'
      raise Shaka::Error.new('gh api failed.', http_status: 502) if login == 'flaky'

      writer = %w[writer writer[bot] writer_corp].include?(login)
      { 'permission' => writer ? 'write' : 'read', 'user' => { 'login' => login } }
    end
  end

  def test_overlapping_snapshots_and_host_handoffs_count_each_response_once
    github = GitHub.new
    journal = Shaka::UsageJournal.new(github, identity: 'id')
    publish(journal, %w[r1 r2], 'commit')
    switched = record('r3', model: 'gpt-6-astra', effort: 'high')
    journal.publish([record('r2'), switched], event: 'testing')
    collected = journal.collect.fetch('records')
    assert_equal(%w[r1 r2 r3], collected.flat_map { |entry| entry['responses'] })
    assert_equal 'high', collected.last['columns'][0]['effort']
  end

  def test_concurrent_stale_readers_append_and_duplicates_do_not_inflate_totals
    github = GitHub.new
    first = Shaka::UsageJournal.new(github, identity: 'id')
    second = Shaka::UsageJournal.new(github, identity: 'id')
    concurrent_publish(github, first, second)
    assert_equal %w[r1 r2], responses(first)
    assert_equal 2, github.writes.size
    publish(first, ['r1'], 'comment')
    assert_equal 2, github.writes.size
  end

  def test_reassociation_keeps_commits_without_recounting_tokens
    github = GitHub.new
    journal = Shaka::UsageJournal.new(github, identity: 'id')
    journal.publish([record('r1')], event: 'commit')
    journal.publish([record('r1', commits: ['b' * 40])], event: 'commit')
    records = journal.collect['records']
    assert_equal 1, records.size
    assert_equal ['a' * 40, 'b' * 40], records[0]['commits']
  end

  def test_malformed_or_untrusted_comments_do_not_become_evidence
    github = GitHub.new
    github.comments << { 'body' => "#{Shaka::UsageJournal::MARK}\nSENSITIVE", 'user' => { 'login' => 'outsider' } }
    assert_empty Shaka::UsageJournal.new(github, identity: 'id').collect['records']
    github.comments[0]['user']['login'] = 'writer'
    assert_raises(Shaka::Error) { Shaka::UsageJournal.new(github, identity: 'id').collect }
  end

  def test_a_failed_chunk_is_retryable_without_republishing_confirmed_records
    github = GitHub.new
    journal = Shaka::UsageJournal.new(github, identity: 'id')
    def journal.body_length(records) = records.size > 1 ? 60_001 : 1

    github.fail_after = 1
    assert_raises(Shaka::Error) { publish(journal, %w[r1 r2 r3], 'comment') }
    github.fail_after = nil
    publish(journal, %w[r1 r2 r3], 'comment')
    assert_equal %w[r1 r2 r3], responses(journal)
    assert_equal 3, github.writes.size
  end

  def test_partially_measured_response_gets_missing_counters_without_losing_known_counts
    original = record('r1')
    original['columns'][0]['reasoning_output'] = 'UNKNOWN'
    reduced = Shaka::UsageJournalRecords.combine([original, record('r1')])
    assert_equal '5', reduced[0]['columns'][0]['reasoning_output']
    assert_equal '$0.10', reduced[0]['columns'][0]['usd']
  end

  def test_conflicting_native_counters_fail_instead_of_producing_a_total
    changed = record('r1')
    changed['columns'][0]['input'] = '999'
    assert_raises(Shaka::Error) { Shaka::UsageJournalRecords.combine([record('r1'), changed]) }
  end

  def test_aggregate_reports_cannot_silently_double_count_partial_overlap
    github = GitHub.new
    aggregate = record('r1').merge('responses' => %w[r1 r2])
    assert_raises(Shaka::Error) { Shaka::UsageJournal.new(github, identity: 'id').publish([aggregate], event: 'commit') }
    assert_empty github.writes
  end

  def test_a_different_host_survives_the_handoff
    github = GitHub.new
    journal = Shaka::UsageJournal.new(github, identity: 'id')
    publish(journal, ['r1'], 'commit')
    journal.publish([record('c1').merge('host' => 'claude-code')], event: 'handoff')
    assert_equal %w[r1 c1], responses(journal)
  end

  private

  def concurrent_publish(github, first, second)
    github.stale = true
    publish(first, ['r1'], 'comment')
    second.publish([record('r1'), record('r2')], event: 'review')
    github.stale = false
  end

  def publish(journal, ids, event) = journal.publish(ids.map { |id| record(id) }, event:)
  def responses(journal) = journal.collect['records'].flat_map { |entry| entry['responses'] }
end

class UsageJournalRecoveryTest < Minitest::Test
  include UsageJournalFixture

  GitHub = UsageJournalTest::GitHub

  def test_saved_null_records_report_a_selection_error
    assert_raises(Shaka::Error) { Shaka::UsageJournalRecords.combine(nil) }
  end

  def test_bot_authors_still_require_verified_write_permission
    github = GitHub.new
    journal = Shaka::UsageJournal.new(github, identity: 'id')
    journal.publish([record('r1')], event: 'commit')
    github.comments[0]['user']['login'] = 'writer[bot]'
    assert_equal(['r1'], journal.collect['records'].flat_map { |entry| entry['responses'] })
  end

  def test_conflicts_and_enrichment_are_checked_before_render_deduplication
    github = GitHub.new
    journal = Shaka::UsageJournal.new(github, identity: 'id')
    changed = record('r1')
    changed['columns'][0]['input'] = '999'
    assert_raises(Shaka::Error) { journal.publish([record('r1'), changed], event: 'commit') }
    assert_empty github.writes
  end

  def test_enrichment_survives_identical_record_identities
    github = GitHub.new
    journal = Shaka::UsageJournal.new(github, identity: 'id')
    changed = record('r1')
    changed['columns'][0]['input'] = 'UNKNOWN'
    journal.publish([changed, record('r1')], event: 'commit')
    assert_equal '100', journal.collect['records'][0]['columns'][0]['input']
  end

  def test_shared_categories_are_stable_on_retries_and_preserve_a_new_role
    github = GitHub.new
    journal = Shaka::UsageJournal.new(github, identity: 'id')
    %w[implementation review integration].each do |role|
      journal.publish([record('r1').merge('contribution' => role)], event: 'review')
    end
    before = journal.collect
    journal.publish([record('r1')], event: 'comment')
    assert_equal before, journal.collect
    assert_equal 3, github.writes.size
  end

  def test_changed_notes_do_not_republish_all_earlier_responses
    github = GitHub.new
    journal = Shaka::UsageJournal.new(github, identity: 'id')
    journal.publish([record('r1')], event: 'commit')
    journal.publish([record('r1').merge('note' => 'Later task scope.')], event: 'comment')
    assert_equal 1, github.writes.size
  end

  def test_shared_attribution_replaces_description_without_recounting
    original = record('r1')
    collected = Shaka::UsageJournalRecords.combine([original, original.merge('contribution' => 'review')])
    assert_equal 'shared-planning', collected[0]['columns'][0]['label']
    body = existing_body(original)
    content, stats = Shaka::UsageRecords.carry({ 'usage' => { 'note' => '', 'records' => collected } }, body)
    assert_equal 1, stats['replaced']
    refute content['usage'].key?('carried')
  end

  private

  def existing_body(original)
    old = Shaka::UsageDetails.new('note' => '', 'records' => [original]).detail
    "<!-- shaka:begin -->\nS\n<details>\n<summary>Usage and cost</summary>\n\n#{old['body']}\n" \
      "</details>\n<!-- shaka:end -->"
  end
end

class UsageJournalSummaryTest < Minitest::Test
  include UsageJournalFixture

  def test_description_summary_preserves_counts_and_identities_without_repeating_notes
    records = Array.new(200) { |number| record("r#{number}") }
    result = Shaka::UsageJournalSummary.compact(records)
    assert_equal 1, result.size
    assert_equal 200, result[0]['responses'].size
    assert_summary_counts(result[0]['columns'][0])
    assert_compact_body(result)
  end

  def assert_compact_body(records)
    body = Shaka::UsageDetails.new('note' => '', 'records' => records).detail['body']
    assert_operator body.bytesize, :<, 60_000
  end

  def assert_summary_counts(column)
    assert_equal '$20.00', column['usd']
    assert_equal '20000', column['input']
  end

  def test_summary_preserves_unknown_fields_and_price_evidence
    first = record('r1')
    first['columns'][0]['output'] = 'UNKNOWN'
    groups = Shaka::UsageJournalSummary.compact([first, record('r2')])
    assert_equal '20 (partial)', groups[0]['columns'][0]['output']
    changed_price = record('r3').merge('note' => 'Different pricing date.')
    assert_equal 2, Shaka::UsageJournalSummary.compact([first, changed_price]).size
  end
end

class UsageJournalPublicationBoundaryTest < Minitest::Test
  include UsageJournalFixture

  def test_first_visible_line_identifies_the_publishing_writer
    github = UsageJournalTest::GitHub.new
    identity = '🤖 Codex · OpenAI · gpt-6.1-sol · medium'
    Shaka::UsageJournal.new(github, identity:).publish([record('response')], event: 'review')
    assert_equal identity, github.writes.first[1][:body].lines[1].strip
  end
end

class UsageJournalRoundTripTest < Minitest::Test
  include UsageJournalFixture

  def test_records_sharing_a_note_keep_it_and_do_not_republish
    github = UsageJournalTest::GitHub.new
    journal = Shaka::UsageJournal.new(github, identity: 'id')
    pair = [record('r1'), record('r2')]
    journal.publish(pair, event: 'commit')
    assert_includes github.writes.first[1][:body], 'usage-note-ref'
    assert_equal ['Native sample.'], notes(journal)
    assert_empty journal.publish(pair, event: 'commit')
  end

  def test_a_whole_task_report_still_dates_the_task_after_collection
    github = UsageJournalTest::GitHub.new
    journal = Shaka::UsageJournal.new(github, identity: 'id')
    journal.publish([record('r1').merge('covers_task' => true), record('r2')], event: 'commit')
    assert_equal({ 'r1' => true, 'r2' => nil }, covers(journal))
  end

  def test_a_later_whole_task_selection_upgrades_a_response_already_published
    github = UsageJournalTest::GitHub.new
    journal = Shaka::UsageJournal.new(github, identity: 'id')
    journal.publish([record('r1')], event: 'commit')
    journal.publish([record('r1').merge('covers_task' => true)], event: 'finish')
    assert_equal 2, github.writes.size
    assert_equal({ 'r1' => true }, covers(journal))
  end

  def test_publishing_without_write_access_reports_that_collection_ignores_it
    github = UsageJournalTest::GitHub.new
    github.author = 'outsider'
    error = assert_raises(Shaka::Error) { reader(github).publish([record('r1')], event: 'commit') }
    assert_includes error.message, 'write access'
  end

  def test_an_unreadable_comment_is_named
    github = UsageJournalTest::GitHub.new
    github.comments << { 'id' => 7, 'html_url' => 'https://example.test/c7', 'user' => { 'login' => 'writer' },
                         'body' => "#{Shaka::UsageJournal::MARK}\nno records" }
    error = assert_raises(Shaka::Error) { reader(github).collect }
    assert_includes error.message, 'https://example.test/c7'
  end

  def test_a_comment_failing_the_record_shape_is_named
    github = UsageJournalTest::GitHub.new
    reader(github).publish([record('r1')], event: 'commit')
    comment = github.comments[0]
    comment['html_url'] = 'https://example.test/c1'
    comment['body'] = comment['body'].sub(/<!-- usage-columns .* -->/, '<!-- usage-columns {} -->')
    error = assert_raises(Shaka::Error) { reader(github).collect }
    assert_includes error.message, 'https://example.test/c1'
  end

  def test_an_enterprise_managed_login_counts_as_a_writer_when_github_says_so
    github = UsageJournalTest::GitHub.new
    github.author = 'writer_corp'
    reader(github).publish([record('r1')], event: 'commit')
    assert_equal ['Native sample.'], notes(reader(github))
  end

  def test_a_conflict_names_the_response
    changed = record('r1')
    changed['columns'] = [changed['columns'][0].merge('input' => '999')]
    error = assert_raises(Shaka::Error) { Shaka::UsageJournalRecords.combine([record('r1'), changed]) }
    assert_includes error.message, 'r1'
  end

  def test_shared_attribution_replaces_a_report_from_a_rebased_commit
    rebased = record('r1', commits: ['b' * 40])
    collected = Shaka::UsageJournalRecords.combine([rebased, rebased.merge('contribution' => 'review')])
    content, stats = Shaka::UsageRecords.carry({ 'usage' => { 'note' => '', 'records' => collected } },
                                               described_body(record('r1')))
    assert_equal [1, ['a' * 40, 'b' * 40]], [stats['replaced'], content['usage']['records'][0]['commits'].sort]
  end

  def test_an_unresolvable_author_is_not_a_writer
    assert_equal ['Native sample.'], notes(reader(github_with_extra_author('gone')))
  end

  def test_a_failed_permission_lookup_stops_collection
    assert_raises(Shaka::Error) { reader(github_with_extra_author('flaky')).collect }
  end

  private

  def github_with_extra_author(login)
    github = UsageJournalTest::GitHub.new
    reader(github).publish([record('r1')], event: 'commit')
    github.comments << github.comments[0].merge('user' => { 'login' => login })
    github
  end

  def described_body(earlier)
    detail = Shaka::UsageDetails.new('note' => '', 'records' => [earlier]).detail
    "<!-- shaka:begin -->\nS\n<details>\n<summary>Usage and cost</summary>\n\n#{detail['body']}\n" \
      "</details>\n<!-- shaka:end -->"
  end

  def covers(journal)
    journal.collect['records'].to_h { |entry| [entry['responses'].first, entry['covers_task']] }
  end
end

class UsageJournalPricingTest < Minitest::Test
  include UsageJournalFixture

  def test_a_known_price_brings_its_own_note
    unpriced = record('r1').merge('note' => 'Unsupported model.')
    unpriced['columns'] = [unpriced['columns'][0].merge('usd' => 'UNKNOWN', 'credits' => 'UNKNOWN')]
    merged = Shaka::UsageJournalRecords.combine([unpriced, record('r1')]).first
    assert_equal '$0.10', merged['columns'][0]['usd']
    assert_equal 'Native sample.', merged['note']
  end

  def test_the_first_measured_price_keeps_its_note
    later = record('r1').merge('note' => 'Later card.')
    later['columns'] = [later['columns'][0].merge('usd' => '$0.20')]
    merged = Shaka::UsageJournalRecords.combine([record('r1'), later]).first
    assert_equal ['$0.10', 'Native sample.'], [merged['columns'][0]['usd'], merged['note']]
  end

  def test_mixed_enrichment_keeps_the_first_measured_prices_and_note_together
    later = priced('$0.20', '9 credits').merge('note' => 'Later card.')
    merged = Shaka::UsageJournalRecords.combine([priced('$0.10', 'UNKNOWN'), later]).first
    assert_equal ['$0.10', 'UNKNOWN', 'Native sample.'],
                 [*merged['columns'][0].values_at('usd', 'credits'), merged['note']]
  end

  private

  def priced(usd, credits)
    entry = record('r1')
    entry.merge('columns' => [entry['columns'][0].merge('usd' => usd, 'credits' => credits)])
  end
end

class UsageJournalEdgeCaseTest < Minitest::Test
  include UsageJournalFixture

  def test_unreadable_responses_across_a_model_switch_stay_separate
    placeholders = %w[model-a model-b].map do |model|
      entry = record('r1').merge('responses' => [], 'complete' => false)
      entry.merge('columns' => [entry['columns'][0].merge('model' => model)])
    end
    assert_equal 2, Shaka::UsageJournalRecords.combine(placeholders).size
  end

  def test_a_comment_edited_on_the_web_still_counts
    github = UsageJournalTest::GitHub.new
    reader(github).publish([record('r1')], event: 'commit')
    github.comments[0]['body'] = github.comments[0]['body'].gsub("\n", "\r\n")
    assert_equal ['Native sample.'], notes(reader(github))
  end

  def test_an_unpriced_response_is_not_republished_when_only_its_note_changes
    github = UsageJournalTest::GitHub.new
    unpriced = record('r1')
    unpriced['columns'] = [unpriced['columns'][0].merge('usd' => 'UNKNOWN', 'credits' => 'UNKNOWN')]
    reader(github).publish([unpriced], event: 'commit')
    assert_empty reader(github).publish([unpriced.merge('note' => 'Another scope.')], event: 'commit')
  end
end
