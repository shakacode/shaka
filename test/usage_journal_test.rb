# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/usage/journal'
require 'shaka/publication/managed_region'

module UsageJournalFixture
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
    attr_accessor :stale, :fail_after

    def initialize
      @repository = 'owner/repo'
      @number = 12
      @comments = []
      @writes = []
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
                                                    'user' => { 'login' => 'writer' })
      @comments << comment
      comment
    end

    def permission(path)
      login = path.split('/')[-2]
      { 'permission' => %w[writer writer[bot]].include?(login) ? 'write' : 'read', 'user' => { 'login' => login } }
    end
  end

  def test_overlapping_snapshots_and_host_handoffs_count_each_response_once
    github = GitHub.new
    journal = Shaka::UsageJournal.new(github)
    publish(journal, %w[r1 r2], 'commit')
    switched = record('r3', model: 'gpt-6-astra', effort: 'high')
    journal.publish([record('r2'), switched], event: 'testing')
    collected = journal.collect.fetch('records')
    assert_equal(%w[r1 r2 r3], collected.flat_map { |entry| entry['responses'] })
    assert_equal 'high', collected.last['columns'][0]['effort']
  end

  def test_concurrent_stale_readers_append_and_duplicates_do_not_inflate_totals
    github = GitHub.new
    first = Shaka::UsageJournal.new(github)
    second = Shaka::UsageJournal.new(github)
    concurrent_publish(github, first, second)
    assert_equal %w[r1 r2], responses(first)
    assert_equal 2, github.writes.size
    publish(first, ['r1'], 'comment')
    assert_equal 2, github.writes.size
  end

  def test_reassociation_keeps_commits_without_recounting_tokens
    github = GitHub.new
    journal = Shaka::UsageJournal.new(github)
    journal.publish([record('r1')], event: 'commit')
    journal.publish([record('r1', commits: ['b' * 40])], event: 'commit')
    records = journal.collect['records']
    assert_equal 1, records.size
    assert_equal ['a' * 40, 'b' * 40], records[0]['commits']
  end

  def test_malformed_or_untrusted_comments_do_not_become_evidence
    github = GitHub.new
    github.comments << { 'body' => "#{Shaka::UsageJournal::MARK}\nSENSITIVE", 'user' => { 'login' => 'outsider' } }
    assert_empty Shaka::UsageJournal.new(github).collect['records']
    github.comments[0]['user']['login'] = 'writer'
    assert_raises(Shaka::Error) { Shaka::UsageJournal.new(github).collect }
  end

  def test_a_failed_chunk_is_retryable_without_republishing_confirmed_records
    github = GitHub.new
    journal = Shaka::UsageJournal.new(github)
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
    assert_raises(Shaka::Error) { Shaka::UsageJournal.new(github).publish([aggregate], event: 'commit') }
    assert_empty github.writes
  end

  def test_a_different_host_survives_the_handoff
    github = GitHub.new
    journal = Shaka::UsageJournal.new(github)
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
    journal = Shaka::UsageJournal.new(github)
    journal.publish([record('r1')], event: 'commit')
    github.comments[0]['user']['login'] = 'writer[bot]'
    assert_equal(['r1'], journal.collect['records'].flat_map { |entry| entry['responses'] })
  end

  def test_conflicts_and_enrichment_are_checked_before_render_deduplication
    github = GitHub.new
    journal = Shaka::UsageJournal.new(github)
    changed = record('r1')
    changed['columns'][0]['input'] = '999'
    assert_raises(Shaka::Error) { journal.publish([record('r1'), changed], event: 'commit') }
    assert_empty github.writes
  end

  def test_enrichment_survives_identical_record_identities
    github = GitHub.new
    journal = Shaka::UsageJournal.new(github)
    changed = record('r1')
    changed['columns'][0]['input'] = 'UNKNOWN'
    journal.publish([changed, record('r1')], event: 'commit')
    assert_equal '100', journal.collect['records'][0]['columns'][0]['input']
  end

  def test_shared_categories_are_stable_on_retries_and_preserve_a_new_role
    github = GitHub.new
    journal = Shaka::UsageJournal.new(github)
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
    journal = Shaka::UsageJournal.new(github)
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

  def test_print_only_cli_results_report_the_named_gap_without_posting
    require 'shaka/usage/journal_command'
    Tempfile.create(['print-only', '.json']) do |file|
      file.write(JSON.generate(usage_records: [], usage_gap: 'Only the call summary survives.'))
      file.close
      _output, error = capture_io do
        assert_equal 1, Shaka::UsageJournalCommand.run(['publish', 'owner/repo', '12', '--content-file', file.path])
      end
      assert_includes error, 'Only the call summary survives.'
      refute_includes error, 'malformed'
    end
  end
end

class UsageJournalRoundTripTest < Minitest::Test
  include UsageJournalFixture

  def test_records_sharing_a_note_keep_it_and_do_not_republish
    github = UsageJournalTest::GitHub.new
    journal = Shaka::UsageJournal.new(github)
    pair = [record('r1'), record('r2')]
    journal.publish(pair, event: 'commit')
    assert_includes github.writes.first[1][:body], 'usage-note-ref'
    assert_equal ['Native sample.'], notes(journal)
    assert_empty journal.publish(pair, event: 'commit')
  end

  def test_a_whole_task_report_still_dates_the_task_after_collection
    github = UsageJournalTest::GitHub.new
    journal = Shaka::UsageJournal.new(github)
    journal.publish([record('r1').merge('covers_task' => true), record('r2')], event: 'commit')
    assert_equal({ 'r1' => true, 'r2' => nil }, covers(journal))
  end

  def test_a_later_whole_task_selection_upgrades_a_response_already_published
    github = UsageJournalTest::GitHub.new
    journal = Shaka::UsageJournal.new(github)
    journal.publish([record('r1')], event: 'commit')
    journal.publish([record('r1').merge('covers_task' => true)], event: 'finish')
    assert_equal 2, github.writes.size
    assert_equal({ 'r1' => true }, covers(journal))
  end

  private

  def notes(journal) = journal.collect['records'].map { |entry| entry['note'] }.uniq

  def covers(journal)
    journal.collect['records'].to_h { |entry| [entry['responses'].first, entry['covers_task']] }
  end
end
