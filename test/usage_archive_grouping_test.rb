# frozen_string_literal: true

require_relative 'description_usage_archive_test'
require_relative 'publication_test'

# Every new head adds review and checkpoint records; archived history must not refill the description.
class UsageArchiveGroupingTest < Minitest::Test
  include UsageRecordsFixture

  # Timings, review history, and the other sections a long PR keeps outside its usage table.
  OTHER_SECTIONS = "<!-- fixture sections #{'x' * 27_000} -->\n".freeze

  def native(round, index, responses: 40)
    DEFAULTS.merge('host' => 'codex', 'sources' => ["round-#{round}-#{index}"], 'contribution' => 'review',
                   'responses' => Array.new(responses) { |i| "round-#{round}-#{index}-response-#{i}" },
                   'columns' => [PublicationUsageTableTest::COLUMN], 'note' => 'Original rate card; UNKNOWN fees.')
  end

  # Two local reviews and a checkpoint, carried onto everything the description already holds.
  def republish(github, round)
    usage = { 'note' => 'Partial coverage.', 'records' => Array.new(3) { |index| native(round, index) } }
    github.description do |pull|
      content, = Shaka::UsageRecords.carry_from({ 'usage' => usage }, pull)
      detail = Shaka::UsageDetails.new(content.fetch('usage')).detail
      "#{OTHER_SECTIONS}<details>\n<summary>#{detail['summary']}</summary>\n\n#{detail['body']}\n\n</details>\n"
    end
    github.stored.fetch('body').length
  end

  def test_sixty_archived_records_leave_room_for_three_more
    github = DescriptionUsageArchiveTest::MemoryGitHub.new
    lengths = (1..20).map { |round| republish(github, round) }
    assert_equal 60, restored_records(github)
    assert_operator late_growth(lengths), :<, 500, 'A republish should add one archive reference, not one per record.'
    republish(github, 21)
    assert_equal 63, restored_records(github)
    assert_operator github.stored['body'].length, :<=, 65_536
  end

  def restored_records(github)
    restored = Shaka::UsageArchive.new(github).expand(github.stored['body'])
    Shaka::UsageRecords.parsed_blocks(restored).size
  end
  private :restored_records

  # The largest step among the last ten publications, all of which archive.
  def late_growth(lengths) = lengths.each_cons(2).map { |before, after| after - before }.last(10).max
  private :late_growth

  def test_a_grouped_reference_that_loses_a_record_is_refused
    github = DescriptionUsageArchiveTest::MemoryGitHub.new
    github.description(body: "#{large_pair}\n")
    damaged = github.stored['body'].sub('"records":[0,1]', '"records":[1]')
    refute_equal github.stored['body'], damaged
    assert_builder_refuses(github, damaged)
  end

  # Each edit below also rewrites the inventory, so only the reference checks can catch it.
  def test_a_grouped_reference_that_repeats_a_record_is_refused
    github = DescriptionUsageArchiveTest::MemoryGitHub.new
    github.description(body: "#{large_pair}\n")
    assert_builder_refuses(github, reinventoried(github.stored['body'].sub('"records":[0,1]', '"records":[1,1]')))
  end

  def test_a_grouped_reference_cannot_restore_a_report_it_does_not_show
    github = DescriptionUsageArchiveTest::MemoryGitHub.new
    legacy = record('codex', 'Legacy', responses: ['legacy-response'], contribution: 'review')
    github.description(body: "#{large_pair}\n\n#{legacy}\n")
    hidden = github.stored['body'].gsub(Shaka::UsageArchive::REFERENCES) do |reference|
      ref = JSON.parse(Regexp.last_match(1))
      ref.key?('record') ? without_report(ref, Regexp.last_match(2)) : reference
    end
    assert_builder_refuses(github, reinventoried(hidden))
  end

  # The report's own reference rewritten as a grouped one, which shows only the archive line.
  def without_report(ref, display)
    grouped = ref.slice('comments', 'sha256').merge('records' => [ref['record']])
    line = display[/^Usage archive: .*\n\z/]
    "#{Shaka::UsageArchive::PREFIX}#{JSON.generate(grouped)} -->\n#{line}#{Shaka::UsageArchive::END_MARK}"
  end
  private :without_report

  def reinventoried(body)
    entries = body.scan(Shaka::UsageArchive::REFERENCES).map do |json, _display|
      ref = JSON.parse(json)
      [*ref.values_at('comments', 'sha256'), ref.fetch('records') { ref['record'] }]
    end
    body.sub(Shaka::UsageArchiveReferences::INVENTORY) do
      "#{Shaka::UsageArchiveReferences::INVENTORY_PREFIX}#{Digest::SHA256.hexdigest(JSON.generate(entries))} -->\n"
    end
  end
  private :reinventoried

  def assert_builder_refuses(github, damaged)
    github.stored['body'] = damaged
    assert_raises(Shaka::Error) { github.description { flunk 'A damaged archive reached the description builder.' } }
    assert_equal damaged, github.stored['body']
  end
  private :assert_builder_refuses

  def large_pair
    usage = { 'note' => '', 'records' => Array.new(2) { |index| native(1, index, responses: 3000) } }
    Shaka::UsageDetails.new(usage).detail['body']
  end
  private :large_pair
end
