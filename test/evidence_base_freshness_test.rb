# frozen_string_literal: true

require_relative 'evidence_fixture'

class EvidenceBaseFreshnessTest < Minitest::Test
  include EvidenceFixture

  def test_stops_before_the_check_when_the_head_is_behind_the_base
    with_origin do |root, ref, origin|
      advance_origin(origin, count: 2)
      marker = File.join(File.dirname(origin), 'ran')
      File.write(File.join(root, '.agents/shaka/bin/test'), "#!/bin/sh\ntouch '#{marker}'\n")
      result, error = run_with_base(root, ref, expected_exit: 1)

      assert_equal 'behind_base', result.fetch('status')
      assert_equal({ 'base' => 'main', 'behind' => 2 }, result.fetch('base_behind'))
      refute_path_exists marker, 'the check must not run'
      assert_includes error, '2 commit(s) behind origin/main'
    end
  end

  def test_reports_the_count_before_the_check_output_when_the_head_matches_the_base
    with_origin do |root, ref, _origin|
      File.write(File.join(root, '.agents/shaka/bin/test'), "#!/bin/sh\necho check-output >&2\n")
      result, error = run_with_base(root, ref)

      assert_equal 'completed', result.fetch('status')
      assert_equal({ 'base' => 'main', 'behind' => 0 }, result.fetch('base_behind'))
      assert_operator error.index('head has every commit on origin/main'), :<, error.index('check-output')
    end
  end

  def test_refuses_a_revision_or_remote_name_as_the_base
    with_origin do |root, ref, _origin|
      [ref, ref[0, 7], 'HEAD', 'origin/main'].each do |base|
        result, error = run_with_base(root, ref, expected_exit: 1, base:)
        assert_nil result
        assert_includes error, '--base takes the base branch name'
      end
    end
  end

  def test_runs_and_reports_zero_when_the_head_is_only_ahead
    with_origin do |root, ref, _origin|
      File.write(File.join(root, 'local.txt'), "ahead\n")
      git(root, 'add', '-A')
      commit(root)
      result, = run_with_base(root, ref)

      assert_equal 'completed', result.fetch('status')
      assert_equal({ 'base' => 'main', 'behind' => 0 }, result.fetch('base_behind'))
    end
  end

  def test_runs_when_the_base_cannot_be_fetched
    with_origin do |root, ref, origin|
      FileUtils.rm_rf(origin)
      result, error = run_with_base(root, ref)

      assert_equal 'completed', result.fetch('status')
      assert_equal 'unknown', result.dig('base_behind', 'behind')
      assert_includes error, 'cannot tell whether the head is behind origin/main'
    end
  end

  def test_without_base_reports_nothing_about_the_base
    with_origin do |root, ref, origin|
      advance_origin(origin, count: 1)
      result = run_check(root, ref)

      assert_equal 'completed', result.fetch('status')
      refute result.key?('base_behind')
    end
  end

  private

  def with_origin
    with_checkout do |root, ref|
      Dir.mktmpdir('shaka-base-origin-') do |directory|
        origin = File.join(directory, 'origin.git')
        system('git', 'init', '--quiet', '--bare', '--initial-branch=main', origin, exception: true)
        git(root, 'branch', '-M', 'main')
        git(root, 'remote', 'add', 'origin', origin)
        git(root, 'push', '--quiet', 'origin', 'main')
        yield root, ref, origin
      end
    end
  end

  def advance_origin(origin, count:)
    Dir.mktmpdir('shaka-base-other-') do |directory|
      other = File.join(directory, 'other')
      system('git', 'clone', '--quiet', origin, other, exception: true)
      count.times do |index|
        File.write(File.join(other, "base-#{index}.txt"), "#{index}\n")
        git(other, 'add', '-A')
        commit(other)
      end
      git(other, 'push', '--quiet', 'origin', 'HEAD:main')
    end
  end

  def run_with_base(root, ref, expected_exit: 0, base: 'main')
    output, error = capture_io do
      assert_equal expected_exit, Shaka::Evidence::Command.run(
        ['run', '--root', root, '--ref', ref, '--repository', 'shakacode/shaka', '--command', 'test', '--base', base]
      )
    end
    [output.empty? ? nil : JSON.parse(output), error]
  end
end
