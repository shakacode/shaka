# frozen_string_literal: true

require_relative 'evidence_fixture'

class EvidenceVerificationTest < Minitest::Test
  include EvidenceFixture

  def test_missing_results_are_not_ready
    with_checkout do |root, ref|
      verdict = verify(root, ref)
      assert_equal 'not_ready', verdict.fetch('status')
      assert_equal %w[validation review], verdict.fetch('missing')
    end
  end

  def test_matching_validation_and_review_results_are_ready
    with_checkout do |root, ref|
      validation = run_check(root, ref, command: 'validate')
      review = review_check(root, ref)
      with_results(validation:, review:) do |paths|
        verdict = verify(root, ref, **paths)
        assert_equal 'ready', verdict.fetch('status')
        statuses = verdict.fetch('checks').values.map { |entries| entries.first.fetch('status') }
        assert_equal %w[bound bound], statuses
      end
    end
  end

  def test_superseded_validation_blocks_readiness
    with_checkout do |root, ref|
      validation = run_check(root, ref, command: 'validate')
      review = review_check(root, ref)
      File.write(File.join(root, '.agents/shaka/bin/validate'), "#!/bin/sh\nexit 1\n")
      with_results(validation:, review:) do |paths|
        verdict = verify(root, ref, **paths)
        assert_equal 'not_ready', verdict.fetch('status')
        assert_equal 'superseded', verdict.fetch('checks').fetch('validation').first.fetch('status')
      end
    end
  end

  def test_bind_output_checks_the_result_it_wraps
    with_checkout do |root, ref|
      validation = bind(root, ref, ref, run_check(root, ref, command: 'validate'))
      review = bind(root, ref, ref, review_check(root, ref))
      with_results(validation:, review:) do |paths|
        assert_equal 'ready', verify(root, ref, **paths).fetch('status')
        File.write(File.join(root, '.agents/shaka/bin/validate'), "#!/bin/sh\nexit 1\n")
        assert_superseded_by_settings validation_entry(verify(root, ref, **paths))
      end
    end
  end

  def test_validate_with_arguments_cannot_satisfy_repository_validation
    with_checkout do |root, ref|
      validation = run_check(root, ref, command: 'validate', arguments: ['test/one_test.rb'])
      with_results(validation:, review: review_check(root, ref)) do |paths|
        reasons = verify(root, ref, **paths).fetch('checks').fetch('validation').first.fetch('reasons')
        assert_includes reasons, 'repository validation used command arguments'
      end
    end
  end

  private

  def validation_entry(verdict) = verdict.fetch('checks').fetch('validation').first

  def assert_superseded_by_settings(entry)
    assert_equal 'superseded', entry.fetch('status')
    assert(entry.fetch('reasons').any? { |reason| reason.start_with?('settings components differ') })
    refute_includes entry.fetch('reasons'), 'repository differs or is missing'
  end
end
