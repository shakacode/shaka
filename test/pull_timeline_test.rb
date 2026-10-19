# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/github/pull_timeline'

# The timeline comes from one paged GraphQL read, and a failed read becomes a reason rather than an error.
class PullTimelineTest < Minitest::Test
  # Answers each page of the timeline query from a list.
  class FakeGitHub
    attr_reader :cursors, :repository, :number

    def initialize(pages)
      @repository = 'owner/repo'
      @number = 7
      @pages = pages
      @cursors = []
    end

    def graphql(_query, variables)
      @cursors << variables[:cursor]
      page = @pages.shift or raise Shaka::Error, 'GraphQL failed or returned missing data.'
      { 'repository' => { 'pullRequest' => page } }
    end
  end

  def page(nodes, next_cursor: nil)
    { 'createdAt' => '2026-10-18T08:00:00Z', 'mergedAt' => '2026-10-18T09:00:00Z', 'closedAt' => nil,
      'commits' => { 'nodes' => [{ 'commit' => { 'committedDate' => '2026-10-18T07:30:00Z' } }] },
      'timelineItems' => { 'pageInfo' => { 'hasNextPage' => !next_cursor.nil?, 'endCursor' => next_cursor },
                           'nodes' => nodes } }
  end

  def event(type, name, minute)
    { '__typename' => type, 'createdAt' => "2026-10-18T08:#{minute}:00Z", 'label' => { 'name' => name } }
  end

  def read(pages) = Shaka::PullTimeline.new(FakeGitHub.new(pages)).call

  def test_reads_every_page_and_keeps_only_attention_labels
    github = FakeGitHub.new([page([event('LabeledEvent', 'documentation', '01'),
                                   event('LabeledEvent', 'awaiting-answer', '10')], next_cursor: 'c1'),
                             page([event('UnlabeledEvent', 'Awaiting-Answer', '40')])])
    timeline = Shaka::PullTimeline.new(github).call
    assert_equal [nil, 'c1'], github.cursors
    labels = timeline['labels'].map { |label| label.values_at('name', 'added') }
    assert_equal [['awaiting-answer', true], ['awaiting-answer', false]], labels
  end

  def test_reports_the_first_commit_and_the_merge
    timeline = read([page([])])
    assert_equal [Time.utc(2026, 10, 18, 7, 30), Time.utc(2026, 10, 18, 9)],
                 timeline.values_at('first_commit', 'merged')
  end

  def test_a_failed_read_is_reported_as_unavailable
    assert_equal({ 'unavailable' => 'GraphQL failed or returned missing data.' }, read([]))
  end

  def test_a_timeline_longer_than_the_page_limit_is_unavailable_rather_than_cut_short
    pages = Array.new(Shaka::PullTimeline::MAX_PAGES) { |index| page([], next_cursor: "c#{index}") }
    assert_match(/more than/, read(pages)['unavailable'])
  end
end
