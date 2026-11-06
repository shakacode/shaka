# frozen_string_literal: true

require_relative 'usage_records_test'
require_relative 'publication_test'
require_relative '../skills/shaka/lib/shaka/publication/usage_archive'

# Remote accounting must survive body limits and fail closed when its comments change.
class UsageArchiveTest < Minitest::Test
  include UsageRecordsFixture

  class Comments
    attr_reader :repository, :number, :comments

    def initialize
      @repository = 'owner/repo'
      @number = 42
      @comments = {}
    end

    def api(path, method: 'GET', fields: {})
      return @comments.fetch(path.split('/').last.to_i) if method == 'GET'

      id = @comments.size + 1
      @comments[id] = { 'id' => id, 'body' => fields.fetch(:body),
                        'issue_url' => 'https://api.github.com/repos/owner/repo/issues/42' }
    end
  end

  def setup
    @github = Comments.new
    @archive = Shaka::UsageArchive.new(@github)
  end

  def large_body
    existing(record('codex', 'UNKNOWN pricing stays visible',
                    responses: Array.new(6000) { |i| "response-#{i}" }))
  end

  def test_oversized_usage_fits_and_round_trips_without_losing_any_bytes
    original = large_body
    assert_operator original.length, :>, 65_536
    plan = @archive.prepare(original)
    compact = plan.publish
    assert_operator compact.length, :<=, 65_536
    assert_includes compact, 'UNKNOWN pricing stays visible'
    assert_equal original, @archive.expand(compact)
    assert_bounded_chunks
  end

  def assert_bounded_chunks
    assert_operator @github.comments.size, :>, 1
    @github.comments.each_value { |comment| assert_operator comment['body'].length, :<=, 65_536 }
  end
  private :assert_bounded_chunks

  def test_normal_and_exact_limit_bodies_do_not_create_archives
    ['ordinary', 'x' * 65_536].each do |body|
      assert_equal body, @archive.prepare(body).publish
    end
    assert_empty @github.comments
  end

  def test_non_usage_overflow_fails_before_any_remote_write
    assert_raises(Shaka::Error) { @archive.prepare('x' * 65_537) }
    assert_empty @github.comments
  end

  def test_visible_overflow_with_usage_fails_before_any_remote_write
    assert_raises(Shaka::Error) { @archive.prepare("#{large_body}#{'x' * 65_536}") }
    assert_empty @github.comments
  end

  def test_tables_unknown_values_and_rate_card_notes_survive_archive_and_carry
    usage = priced_usage
    original = Shaka::UsageDetails.new(usage).detail
    body = existing(original.fetch('body'))
    restored = @archive.expand(@archive.prepare(body).publish)
    carried, stats = Shaka::UsageRecords.carry({ 'usage' => usage }, restored)
    assert_equal 1, stats['replaced']
    assert_equal original, Shaka::UsageDetails.new(carried.fetch('usage')).detail
  end

  def priced_usage
    fields = DEFAULTS.merge('host' => 'codex', 'responses' => Array.new(6000) { |i| "response-#{i}" },
                            'columns' => [PublicationUsageTableTest::COLUMN],
                            'note' => 'Original rate card; UNKNOWN fees.')
    { 'note' => 'Partial coverage; not zero.', 'records' => [fields] }
  end
  private :priced_usage

  def test_archiving_never_removes_human_text_or_checkpoint_warnings
    body = "Keep this warning.\n#{large_body}\nHuman footer."
    compact = @archive.prepare(body).publish
    assert compact.start_with?('Keep this warning.')
    assert compact.end_with?('Human footer.')
    assert_equal body, @archive.expand(compact)
  end

  def test_restoration_does_not_replace_a_human_quote_of_the_managed_region
    compact = @archive.prepare(large_body).publish
    quoted = Shaka::Publishing.managed_region(compact)
    expanded = @archive.expand("#{quoted}\n#{compact}")
    assert expanded.start_with?(quoted), 'A quoted copy outside the managed region must stay unchanged.'
    assert_equal Shaka::Publishing.managed_region(large_body), Shaka::Publishing.managed_region(expanded)
  end

  def test_missing_or_modified_archive_blocks_carry
    compact = @archive.prepare(large_body).publish
    @github.comments[1]['body'] += 'tampered'
    assert_raises(Shaka::Error) { @archive.expand(compact) }
    @github.comments.delete(1)
    assert_raises(Shaka::Error) { @archive.expand(compact) }
  end

  def test_a_reference_cannot_read_a_comment_from_another_pull_request
    compact = @archive.prepare(large_body).publish
    @github.comments[1]['issue_url'] = 'https://api.github.com/repos/owner/repo/issues/99'
    assert_raises(Shaka::Error) { @archive.expand(compact) }
  end

  def test_republication_reuses_verified_archives_and_deduplicates_before_archiving
    old = record('codex', 'old', responses: Array.new(6000) { |i| "response-#{i}" })
    compact = @archive.prepare(existing(old)).publish
    count = @github.comments.size
    restored = @archive.expand(compact)
    assert_equal compact, @archive.prepare(restored).publish
    assert_equal count, @github.comments.size
  end

  def test_restored_records_can_be_replaced_by_an_extended_snapshot
    restored = @archive.expand(@archive.prepare(large_body).publish)
    fresh = record('codex', 'fresh', responses: Array.new(6001) { |i| "response-#{i}" })
    content, stats = Shaka::UsageRecords.carry(described(fresh), restored)
    assert_equal 1, stats['replaced']
    refute_includes content['details'].first['body'], 'UNKNOWN pricing stays visible'
  end
end
