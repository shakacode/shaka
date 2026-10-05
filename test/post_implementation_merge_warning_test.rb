# frozen_string_literal: true

require_relative 'post_implementation_publication_test'

class PostImplementationMergeWarningTest < Minitest::Test
  include PostImplementationPublicationFixture

  def domain_block(result)
    report = JSON.parse(File.read(result['report']))
    report.merge!('conclusion' => 'Do not merge', 'summary' => 'Domain acceptance is pending.',
                  'concerns' => ['Fallback continuity needs a maintainer decision.'])
    File.write(result['report'], JSON.generate(report))
  end

  def assert_warning(github)
    assert github.snapshot['isDraft']
    assert_includes github.description_body, 'Domain acceptance is pending.'
    assert_includes github.description_body, 'https://github.com/example/test/pull/1#issuecomment-1'
    assert_operator github.description_body.index('Do not merge'), :<,
                    github.description_body.index('Feature summary')
  end

  def test_blocked_report_makes_the_pr_draft_and_puts_the_reason_before_the_feature_summary
    with_result do |result, path|
      domain_block(result)
      github, status = publish(result, path)

      assert_equal 0, status
      assert_warning(github)
    end
  end
end

class PostImplementationMergeWarningLifecycleTest < Minitest::Test
  include PostImplementationPublicationFixture

  def block(result)
    result.merge!('status' => 'not_completed', 'reason' => 'Review execution failed.')
  end

  def test_retry_preserves_human_text_and_does_not_duplicate_the_warning
    with_result do |result, path|
      block(result)
      github, = publish(result, path)
      publish(result, path, github:)

      assert_equal 1, github.description_body.scan(Shaka::PostImplementationMergeWarning::OPEN).size
      assert github.description_body.end_with?('Human notes')
      assert_includes github.description_body, "<!-- shaka:begin -->\nFeature summary\n<!-- shaka:end -->"
    end
  end

  def test_ready_removes_warning_but_does_not_mark_ready_or_remove_human_text
    with_result do |result, path|
      github, = publish(block(result.dup), path)
      assert_equal 0, publish(result, path, github:)[1]

      refute_includes github.description_body, Shaka::PostImplementationMergeWarning::OPEN
      assert github.snapshot['isDraft']
      assert github.description_body.end_with?('Human notes')
    end
  end

  def test_opt_out_does_not_remove_an_existing_substantive_warning
    with_result do |result, path|
      github, = publish(block(result.dup), path)
      body = github.description_body
      outcome = publish(result.merge('status' => 'opted_out', 'reason' => 'Owner opted out'), path, github:)

      assert_equal 0, outcome[1]
      assert_equal body, github.description_body
      assert github.snapshot['isDraft']
    end
  end

  def test_draft_failure_reports_partial_publication_without_claiming_success
    with_result do |result, path|
      github = GitHub.new('a' * 40)
      github.define_singleton_method(:graphql) { |*, **| raise Shaka::Error, 'Draft conversion denied' }
      outcome = publish(block(result), path, github:)

      assert_equal 1, outcome[1]
      assert_equal({ 'state' => 'failed', 'reason' => 'Draft conversion denied', 'head' => 'a' * 40 },
                   JSON.parse(outcome[2]).fetch('merge_safeguard'))
      assert_includes github.description_body, 'Do not merge'
    end
  end

  def test_ambiguous_warning_markers_leave_the_pr_draft_and_preserve_its_body
    with_result do |result, path|
      github = GitHub.new('a' * 40)
      body = "Human note\n#{Shaka::PostImplementationMergeWarning::OPEN}\nBroken warning"
      github.instance_variable_set(:@description_body, body)
      outcome = publish(block(result), path, github:)

      assert_equal 1, outcome[1]
      assert github.snapshot['isDraft']
      assert_equal body, github.description_body
    end
  end

  def test_description_edit_during_preparation_is_preserved_and_reported
    with_result do |result, path|
      github = GitHub.new('a' * 40)
      github.define_singleton_method(:verify_rendering) do |_body|
        @description_body = 'Concurrent human edit'
      end
      outcome = publish(block(result), path, github:)

      assert_equal 1, outcome[1]
      assert_equal 'Concurrent human edit', github.description_body
      assert_includes outcome[2], 'changed while this update was prepared'
    end
  end

  def test_old_execution_cannot_clear_a_newer_blocker
    with_result do |result, path|
      github, = publish(block(result.dup), path)
      body = github.description_body
      github.define_singleton_method(:issue_comments) do
        [@published, @published.merge('id' => 2, 'body' => @published['body'].sub('abc12345', 'def56789'))]
      end
      outcome = publish(result, path, github:)

      assert_equal 'superseded', JSON.parse(outcome[2]).dig('merge_safeguard', 'state')
      assert_equal body, github.description_body
    end
  end
end

class PostImplementationMergeWarningPreservationTest < Minitest::Test
  include PostImplementationPublicationFixture

  def failed(result) = result.merge('status' => 'not_completed', 'reason' => 'Provider failed')

  def test_feature_description_refresh_preserves_the_warning_before_the_new_summary
    ["<!-- shaka:begin -->\nFeature summary\n<!-- shaka:end -->", 'Original summary'].each do |original|
      assert_refresh_preserves_warning(original)
    end
  end

  def assert_refresh_preserves_warning(original)
    with_result do |result, path|
      github = GitHub.new('a' * 40)
      github.instance_variable_set(:@description_body, "#{original}\n\nHuman notes")
      publish(failed(result), path, github:)
      refreshed = github.send(:merge, github.description_body, "Updated feature summary\n")
      assert_includes refreshed, 'Do not merge'
      assert_operator refreshed.index('Do not merge'), :<, refreshed.index('Updated feature summary')
      assert refreshed.end_with?('Human notes')
    end
  end

  def test_head_moving_during_draft_conversion_prevents_description_write
    with_result do |result, path|
      github = GitHub.new('a' * 40)
      github.define_singleton_method(:graphql) do |*, **|
        @head = 'b' * 40
        super(Shaka::PostImplementationMergeWarning::DRAFT)
      end
      outcome = publish(failed(result), path, github:)
      assert_equal 1, outcome[1]
      refute_includes github.description_body, Shaka::PostImplementationMergeWarning::OPEN
    end
  end

  def test_description_failure_retains_the_draft_and_published_report
    with_result do |result, path|
      github = GitHub.new('a' * 40)
      github.define_singleton_method(:api) do |*args, **options|
        raise Shaka::Error, 'Description denied' if options[:method] == 'PATCH'

        super(*args, **options)
      end
      outcome = publish(failed(result), path, github:)
      assert_equal 1, outcome[1]
      assert github.snapshot['isDraft']
    end
  end
end

class PostImplementationMergeWarningListingTest < Minitest::Test
  include PostImplementationPublicationFixture

  def test_a_stale_comment_listing_is_a_failed_safeguard_instead_of_a_superseded_success
    with_result do |result, path|
      github = GitHub.new('a' * 40)
      github.define_singleton_method(:issue_comments) { [@published.merge('id' => 0)] }
      outcome = publish(result.merge('status' => 'not_completed', 'reason' => 'Provider failed'), path, github:)
      assert_equal 1, outcome[1]
      assert_equal 'failed', JSON.parse(outcome[2]).dig('merge_safeguard', 'state')
      assert_includes outcome[2], 'absent from the comment listing'
    end
  end
end
