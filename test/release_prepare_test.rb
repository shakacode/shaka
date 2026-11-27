# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'shellwords'
require_relative 'release_preflight_helpers'
require_relative 'support/release_behavior_fixture'

# Inputs for the release prepare tests: behavior batches and a validation helper.
module ReleasePrepareInputs
  def write_behavior_records
    _commit, records = ReleaseBehaviorFixture::Records.passing(File.join(@root, 'skills/shaka'))
    path = File.join(@directory, 'release-records.json')
    File.write(path, JSON.generate(records))
    path
  end

  # Answers `evidence run` with the fixture's result and passes every other call to the real helper.
  def fake_helper
    path = File.join(@directory, 'helper')
    File.write(path, <<~RUBY)
      #!#{RbConfig.ruby}
      exec(#{File.join(ReleasePreflightHelpers::ROOT, 'skills/shaka/scripts/shaka').inspect}, *ARGV) unless ARGV.first(2) == %w[evidence run]
      print File.read(#{@validation.inspect})
    RUBY
    File.chmod(0o755, path)
    path
  end

  # The printed next step survives a path with spaces when pasted into a shell.
  def assert_publish_hint(approval)
    assert_equal ['bin/release', 'publish', '--approval', approval], Shellwords.split(@output.lines.last)
  end
end

# Each fixture builds a gem, so related cases share one test. The command runs in a child
# process because loading the fixture's gemspec redefines Shaka::VERSION.
class ReleasePrepareTest < Minitest::Test
  include ReleasePreflightHelpers
  include ReleasePrepareInputs

  RELEASE = File.join(ROOT, 'bin/release')

  def test_writes_an_approval_for_the_built_gem_without_changing_the_checkout
    approval = prepare('--shaka', fake_helper, '--skip-behavior-gate')
    assert_equal [@head, '0.1.0.pre.99', 'ready_for_approval'], approval.values_at('commit', 'version', 'status')
    assert_equal({ 'status' => 'skipped' }, approval.fetch('behavior_gate'))
    assert_equal "A tested prerelease.\n", File.read(approval.fetch('notes'))
    assert_equal approval, JSON.parse(File.read(File.join(@used_out, 'approval.json')))
    assert_equal '', execute('git', 'status', '--porcelain')
  end

  def test_binds_the_built_gem_and_the_helper_validation_result
    approval = prepare('--shaka', fake_helper, '--skip-behavior-gate')
    out = File.realpath(@used_out)
    assert_equal Digest::SHA256.file(approval.fetch('gem')).hexdigest, approval.fetch('gem_sha256')
    assert_publish_hint("#{out}/approval.json")
    # Without --validation, the helper's evidence run result is saved and bound.
    assert_equal "#{out}/validation.json", approval.fetch('validation')
    assert_equal Digest::SHA256.file(@validation).hexdigest, approval.fetch('validation_sha256')
  end

  def test_a_passing_behavior_batch_is_recorded_with_its_checker_result
    records = write_behavior_records
    approval = prepare('--behavior-records', records)
    status, (record, *others) = approval.fetch('behavior_gate').values_at('status', 'records')
    assert_equal ['passed', []], [status, others]
    assert_equal Digest::SHA256.file(records).hexdigest, record.fetch('sha256')
    assert_equal 'passed', JSON.parse(File.read(record.fetch('result'))).fetch('status')
  end

  def test_refuses_a_behavior_batch_for_an_earlier_commit
    records = write_behavior_records
    execute('git', '-c', 'user.name=T', '-c', 'user.email=t@example.com', 'commit', '--allow-empty', '-qm', 'Next')
    execute('git', 'push', '-q', 'origin', 'HEAD:refs/heads/main')
    assert_refused_prepare('release behavior batch did not pass', '--behavior-records', records)
  end

  def test_refuses_an_untrusted_helper_or_a_dirty_checkout_before_running_either
    marker = File.join(@directory, 'helper-ran')
    helper = File.join(@root, 'helper')
    File.write(helper, "#!/bin/sh\ntouch #{marker}\n")
    File.chmod(0o755, helper)
    assert_refused_prepare('outside the release checkout', '--shaka', helper, '--skip-behavior-gate')
    File.unlink(helper)
    File.write(File.join(@root, 'shaka.gemspec'), "File.write(#{marker.inspect}, '')\n", mode: 'a')
    assert_refused_prepare('clean checkout', '--skip-behavior-gate')
    refute_path_exists marker
  end

  def test_refuses_before_building_without_a_passing_behavior_choice
    gate = '--behavior-records or --skip-behavior-gate'
    assert_refused_prepare(gate)
    assert_refused_prepare(gate, '--skip-behavior-gate', '--behavior-records', @validation)
    records = File.join(@directory, 'records.json')
    File.write(records, '[]')
    assert_refused_prepare('release behavior batch', '--behavior-records', records)
    File.write(records, 'not json')
    assert_refused_prepare('unreadable or invalid', '--behavior-records', records)
  end

  def test_refuses_an_output_directory_inside_the_checkout_or_already_used
    @out = File.join(@root, 'tmp/release')
    assert_refused_prepare('outside the release checkout', '--skip-behavior-gate')
    @out = File.join(@directory, 'used')
    FileUtils.mkdir_p(@out)
    File.write(File.join(@out, 'approval.json'), '{}')
    assert_refused_prepare('must not exist yet', '--skip-behavior-gate')
    assert_equal '{}', File.read(File.join(@out, 'approval.json'))
  end

  def test_refuses_a_version_without_a_changelog_entry
    File.write(File.join(@root, 'CHANGELOG.md'), "# Changelog\n")
    execute('git', '-c', 'user.name=Release Test', '-c', 'user.email=test@example.com', 'commit', '-qam', 'Drop')
    execute('git', 'push', '-q', 'origin', 'HEAD:refs/heads/main')
    assert_refused_prepare('no entry for 0.1.0.pre.99', '--skip-behavior-gate')
  end

  private

  def run_prepare(*arguments)
    # Each run needs a new output directory unless the test chose one.
    @used_out = @out || File.join(@directory, "release out #{@runs = @runs.to_i + 1}")
    unless arguments.include?('--shaka')
      arguments = ['--shaka', File.join(ROOT, 'skills/shaka/scripts/shaka'), '--validation', @validation,
                   *arguments]
    end
    Open3.capture3(RbConfig.ruby, RELEASE, 'prepare', '--out', @used_out, *arguments, chdir: @root)
  end

  def prepare(*)
    output, error, status = run_prepare(*)
    assert_predicate status, :success?, error
    @output = output
    JSON.parse(output[/\A\{.*?^\}/m])
  end

  def assert_refused_prepare(message, *)
    _output, error, status = run_prepare(*)
    refute_predicate status, :success?
    assert_includes error, message
  end
end
