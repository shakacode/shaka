# frozen_string_literal: true

require_relative 'post_implementation_publication_test'
require 'shaka/post_implementation/evidence'

# The description shows the rating and reasons a published checkpoint printed, read back from that checkpoint.
class PostImplementationPublishedRiskTest < Minitest::Test
  include PostImplementationPublicationFixture

  HEAD = 'a' * 40
  RISK_MODULE = Shaka::PostImplementationRisk
  READER = Shaka::PostImplementationPublishedRisk

  def published(rating:, reasons:, conclusion: 'Proceed', concerns: [])
    with_result do |result, path|
      report = JSON.parse(File.read(result['report']))
      File.write(result['report'], JSON.generate(report.merge('risk' => { 'rating' => rating, 'reasons' => reasons },
                                                              'conclusion' => conclusion, 'concerns' => concerns)))
      github, status = publish(result, path)
      assert_equal 0, status
      return github
    end
  end

  def test_a_published_checkpoint_gives_back_its_rating_reasons_and_link
    github = published(rating: 'medium', reasons: ['Shared code path.', 'A revert undoes it.'])
    found = Shaka::PostImplementationEvidence.new(github).published_risk(HEAD)

    assert_equal({ 'rating' => 'medium', 'reasons' => ['Shared code path.', 'A revert undoes it.'],
                   'url' => 'https://github.com/example/test/pull/1#issuecomment-1' }, found)
    assert_nil Shaka::PostImplementationEvidence.new(github).published_risk('b' * 40)
  end

  def test_a_blocked_checkpoint_still_shows_the_rating_it_printed
    github = published(rating: 'high', reasons: ['Changes stored data.'], conclusion: 'Simplify/reframe')
    evidence = Shaka::PostImplementationEvidence.new(github)

    assert_equal 'high', evidence.published_risk(HEAD)['rating']
    assert_nil evidence.risk(HEAD), 'merge still reads only a ready checkpoint'
  end

  # Trusted settings carrying the packaged areas and merge settings.
  SEAM = Struct.new(:high_risk_areas, :medium_risk_areas, :merge)
               .new(*Shaka::PostImplementationRisk.areas(nil), {}).freeze

  def test_the_description_assessment_applies_the_areas_merge_applies
    github = published(rating: 'low', reasons: ['Docs only.'])
    def github.api_list(path) = path.include?('/files') ? [{ 'filename' => 'db/migrate/1_add.rb' }] : super
    def github.api(path, **) = super.merge('changed_files' => 1)
    assessment = READER.assessment(SEAM, github, HEAD, Shaka::PostImplementationEvidence.new(github))

    assert_equal %w[low high], assessment.values_at('rating', 'level')
    assert_equal [{ 'area' => 'database', 'path' => 'db/migrate/1_add.rb' }], assessment['areas_hit']
    assert_equal ['Docs only.'], assessment['reasons']
  end

  # Merge stops on a head that moves while it reads the files; the description does not rate them unread instead.
  def test_a_head_that_moves_while_the_files_are_read_stops_the_description
    github = published(rating: 'low', reasons: ['Docs only.'])
    def github.api(path, **) = super.merge('head' => { 'sha' => 'b' * 40 })

    assert_raises(Shaka::PullChangedFiles::Moved) do
      READER.assessment(SEAM, github, HEAD, Shaka::PostImplementationEvidence.new(github))
    end
  end

  # Without trusted settings a rated head withholds its level, while an unrated one stays not rated.
  def test_missing_trusted_settings_withhold_only_a_rated_level
    github = published(rating: 'low', reasons: ['Docs only.'])

    assert_equal READER::WITHHELD, READER.assessment(nil, github, HEAD, Shaka::PostImplementationEvidence.new(github))
    assert_nil READER.assessment(nil, github, 'b' * 40, Shaka::PostImplementationEvidence.new(github))
  end

  def test_no_checkpoint_comment_reads_as_no_rating
    client = Struct.new(:issue_comments, :viewer_login).new([], 'test-author')

    assert_nil Shaka::PostImplementationEvidence.new(client).published_risk(HEAD)
  end

  def section(reasons, paths_read: true)
    assessment = RISK_MODULE.assess('low', {}, paths_read ? ['README.md'] : nil)
    "Before\n\n#{RISK_MODULE.section(assessment, reasons)}\n\nAfter"
  end

  def test_the_line_ruby_adds_is_not_read_as_the_reviewers
    assert_equal ['Docs only.'], READER.reasons_in(section(['Docs only.'], paths_read: false))
  end

  def test_a_reason_with_folding_or_marker_markup_drops_them_all
    ['Ends </details> early.', 'Plants <!-- shaka:begin -->.', 'Opens <summary>x</summary>.'].each do |hostile|
      assert_empty READER.reasons_in(section(['Fine.', hostile])), hostile
    end
    assert_equal ['Renders `<Component>`.'], READER.reasons_in(section(['Renders `<Component>`.']))
  end

  def test_a_reason_the_description_would_refuse_drops_them_all
    assert_empty READER.reasons_in(section(['Fine.', 'Splits on a literal \\n in prose.']))
    assert_equal ['Splits on `\\n`.'], READER.reasons_in(section(['Splits on `\\n`.']))
  end

  def test_windows_line_endings_and_missing_sections_are_handled
    assert_equal ['Docs only.'], READER.reasons_in(section(['Docs only.']).gsub("\n", "\r\n"))
    assert_empty READER.reasons_in('No risk section here.')
  end
end
