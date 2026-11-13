# frozen_string_literal: true

require_relative 'usage_records_test'
require 'shaka/github'

# Exercise publication, remote recovery, and carry together without a live PR.
class DescriptionUsageArchiveTest < Minitest::Test
  include UsageRecordsFixture

  class MemoryGitHub < Shaka::GitHub
    attr_accessor :stored
    attr_reader :comments, :writes

    def initialize
      super('owner/repo', 42)
      @stored = { 'body' => '', 'head' => { 'sha' => 'a' * 40, 'repo' => { 'full_name' => repository } },
                  'base' => { 'sha' => 'b' * 40, 'repo' => { 'full_name' => repository } } }
      @comments = {}
      @writes = []
    end

    def api(path, method: 'GET', fields: {})
      return @stored.dup if path.end_with?('/pulls/42') && method == 'GET'
      return @stored = @stored.merge('body' => fields.fetch(:body)) if method == 'PATCH'
      return @comments.fetch(path.split('/').last.to_i) if method == 'GET'

      @writes << path
      id = @comments.size + 1
      @comments[id] = { 'id' => id, 'body' => fields.fetch(:body),
                        'issue_url' => 'https://api.github.com/repos/owner/repo/issues/42' }
    end

    def markdown(body) = "<p>Summary.</p>#{'<table><tr><td>Usage</td></tr></table>' * body.scan('| ---').size}"
  end

  class VisibilityChangeGitHub < MemoryGitHub
    def api(request, **options)
      super.tap do
        next unless options[:method] == 'POST'

        @stored = @stored.merge('base' => { 'sha' => 'b' * 40, 'repo' => { 'visibility' => 'public' } })
      end
    end
  end

  def large_record
    commits = Array.new(1800) { |index| format('%040x', index) }
    record('codex', 'Measured implementation', commits:, sources: ['private-source-id'],
                                               responses: ['private-response-id'])
  end

  def test_oversized_description_publishes_and_a_new_client_restores_before_carry
    github = MemoryGitHub.new
    github.description(body: "#{large_record}\n")
    assert_operator github.stored['body'].length, :<=, 65_536
    assert_includes github.stored['body'], 'Usage archive:'
    assert_carry_recovery(github)
  end

  def assert_carry_recovery(github)
    fresh = record('claude-code', 'Independent review', responses: ['review-response'], contribution: 'review')
    github.description do |pull|
      refreshed_body(fresh, pull)
    end
    assert_includes github.stored['body'], 'Independent review'
    restored = Shaka::UsageArchive.new(github).expand(github.stored['body'])
    assert_equal 2, Shaka::UsageRecords.parsed_blocks(restored).size
    refute_match(/private-(?:source|response)-id/, restored)
  end
  private :assert_carry_recovery

  def refreshed_body(fresh, pull)
    carried, stats = Shaka::UsageRecords.carry_from(described(fresh), pull)
    assert_equal 1, stats['retained']
    "#{carried.fetch('details').first.fetch('body')}\n"
  end
  private :refreshed_body

  def test_missing_archive_prevents_the_description_builder_and_all_writes
    github = MemoryGitHub.new
    github.description(body: "#{large_record}\n")
    original = github.stored['body']
    github.comments.delete(1)
    assert_raises(Shaka::Error) { github.description { flunk 'Must restore accounting before building a replacement.' } }
    assert_equal original, github.stored['body']
  end

  def test_a_private_repository_keeps_archive_identities_for_accounting
    github = MemoryGitHub.new
    github.stored['base']['repo']['visibility'] = 'private'
    github.description(body: "#{large_record}\n")

    restored = Shaka::UsageArchive.new(github).expand(github.stored.fetch('body'))
    assert_includes restored, 'private-source-id'
    assert_includes restored, 'private-response-id'
  end

  def test_a_concurrent_edit_prevents_archive_uploads
    github = MemoryGitHub.new
    github.define_singleton_method(:markdown) do |body|
      @stored['body'] = 'Concurrent human edit.'
      super(body)
    end
    assert_raises(Shaka::Error) { github.description(body: "#{large_record}\n") }
    assert_empty github.writes
    assert_equal 'Concurrent human edit.', github.stored['body']
  end

  def test_a_visibility_change_prevents_native_archive_uploads
    github = MemoryGitHub.new
    github.stored['base']['repo']['visibility'] = 'private'
    github.define_singleton_method(:markdown) do |body|
      @stored = @stored.merge('base' => { 'sha' => 'b' * 40, 'repo' => { 'visibility' => 'public' } })
      super(body)
    end

    assert_raises(Shaka::Error) { github.description(body: "#{large_record}\n") }
    assert_empty github.writes
    assert_empty github.stored.fetch('body')
  end

  def test_a_visibility_change_stops_remaining_archive_parts
    github = VisibilityChangeGitHub.new
    github.stored['base']['repo']['visibility'] = 'private'

    assert_raises(Shaka::Error) { github.description(body: "#{large_record}\n") }
    assert_equal 1, github.comments.size
    assert_empty github.stored.fetch('body')
  end

  def test_an_archive_upload_failure_does_not_replace_the_description
    github = MemoryGitHub.new
    github.define_singleton_method(:api) do |path, **options|
      raise Shaka::Error, 'Upload unavailable.' if options[:method] == 'POST' && @comments.any?

      super(path, **options)
    end
    assert_raises(Shaka::Error) { github.description(body: "#{large_record}\n") }
    assert_empty github.stored['body']
    assert_equal 1, github.comments.size
  end
end
