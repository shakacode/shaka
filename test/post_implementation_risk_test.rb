# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/post_implementation/risk'
require 'shaka/repository_config'

class PostImplementationRiskTest < Minitest::Test
  RISK = Shaka::PostImplementationRisk
  AREAS = Shaka::RepositoryConfig::HighRiskAreasSchema.effective(nil)

  def test_a_high_risk_area_raises_any_rating_to_high
    assessment = RISK.assess('low', AREAS, ['app/models/user.rb', 'db/migrate/20260101_add_index.rb'])
    assert_equal 'high', assessment['level']
    assert_equal [{ 'area' => 'database', 'path' => 'db/migrate/20260101_add_index.rb' }], assessment['areas_hit']
    assert_includes RISK.section(assessment, ['Adds an index.']), "raised from the reviewer's low by `database`"
  end

  def test_a_file_name_cannot_end_its_code_span
    hostile = "db/migrate/x` [click](https://example.invalid) `\n@someone.rb"
    section = RISK.section(RISK.assess('low', AREAS, [hostile]), ['Adds a migration.'])
    assert_includes section, '(`db/migrate/x? [click](https://example.invalid) ??@someone.rb`)'
  end

  def test_default_areas_cover_persistence_infrastructure_and_ci
    { 'config/storage.yml' => 'persistence', 'deploy/main.tf' => 'infrastructure',
      'services/api/Dockerfile' => 'infrastructure', '.github/workflows/ci.yml' => 'ci_and_trust',
      '.agents/shaka/config.yml' => 'shaka', 'Infra/main.tf' => 'infrastructure',
      'app/dockerfile' => 'infrastructure' }.each do |path, area|
      assert_equal [area], RISK.assess('low', AREAS, [path])['areas_hit'].map { it['area'] }, path
    end
  end

  def test_the_rating_stands_outside_high_risk_areas
    assessment = RISK.assess('medium', AREAS, ['app/models/user.rb', 'README.md'])
    assert_equal %w[medium medium], assessment.values_at('rating', 'level')
    section = RISK.section(assessment, ['Changes a shared model.'])
    assert_includes section, 'meant for a person to merge after a skim'
    assert_includes section, '- Changes a shared model.'
    assert_includes section, 'does not change what merges until'
  end

  def test_unreadable_changed_files_count_as_unread
    [Shaka::Error.new('GitHub is down'), Errno::EACCES.new('gh')].each do |failure|
      github = Object.new
      def github.repository = 'shakacode/shaka'
      def github.number = 1
      github.define_singleton_method(:api) { |*| raise failure }
      assessment = RISK.from(nil, github, 'a' * 40, 'low')
      assert_equal ['high', false], assessment.values_at('level', 'paths_read'), failure.class.name
    end
  end

  def test_unknown_ratings_and_unread_files_count_as_high
    assert_equal 'high', RISK.assess('unknown', AREAS, ['README.md'])['level']
    unread = RISK.assess('low', AREAS, nil)
    assert_equal 'high', unread['level']
    assert_includes RISK.section(unread, ['Docs only.']), 'high-risk areas were not checked'
  end

  def test_a_repository_list_replaces_an_area_and_an_empty_list_turns_it_off
    areas = Shaka::RepositoryConfig::HighRiskAreasSchema.effective('database' => [], 'billing' => ['app/billing/**/*'])
    assessment = RISK.assess('low', areas, ['db/migrate/1_x.rb', 'app/billing/invoice.rb'])
    assert_equal(['billing'], assessment['areas_hit'].map { it['area'] })
  end

  def test_invalid_areas_are_refused
    { [] => 'must be a mapping', { 'Bad Name' => ['x'] } => 'lowercase words',
      { 'database' => 'db/**' } => 'list of path patterns' }.each do |areas, message|
      error = assert_raises(Shaka::Error) { Shaka::RepositoryConfig::HighRiskAreasSchema.new(areas).validate }
      assert_includes error.message, message
    end
  end
end

class PostImplementationRiskReportTest < Minitest::Test
  REPORT = { 'head' => 'a' * 40, 'conclusion' => 'Proceed', 'reasons' => ['Useful.'], 'concerns' => [],
             'alternative' => 'No change.', 'verification_adequacy' => ADEQUACY }.freeze

  def read(report)
    Tempfile.create(['checkpoint', '.json']) do |file|
      file.write(JSON.generate(report))
      file.flush
      Shaka::PostImplementationReport.read(file.path, head: 'a' * 40)
    end
  end

  def test_a_report_from_before_risk_ratings_counts_as_unknown
    assert_equal 'unknown', read(REPORT).dig('risk', 'rating')
  end

  def test_a_risk_rating_needs_reasons
    assert_equal RISK, read(REPORT.merge('risk' => RISK))['risk']
    [{ 'rating' => 'critical', 'reasons' => ['x'] }, { 'rating' => 'low', 'reasons' => [] },
     { 'rating' => 'low', 'reasons' => ["two\nlines"] }].each do |risk|
      assert_raises(Shaka::Error, risk.inspect) { read(REPORT.merge('risk' => risk)) }
    end
  end
end
