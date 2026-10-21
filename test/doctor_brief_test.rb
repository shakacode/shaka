# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'doctor_helper'
require 'stringio'

# The start check tells a user, before a task begins, which Shaka and which settings it uses.
class DoctorBriefTest < Minitest::Test
  include DoctorHelper

  INSTALLED = { 'version' => '0.1.0', 'package_id' => 'p',
                'source' => { 'kind' => 'revision', 'revision' => '2363e217b6034b4b684ef88f2a29ddda458d870f' } }.freeze
  COPIED = { 'version' => '0.1.0', 'package_id' => nil, 'source' => { 'kind' => 'uninstalled' } }.freeze
  PATH = '.agents/shaka/config.yml'

  def test_a_ready_installation_lists_the_installation_settings_and_basic_checks
    report, blocked = brief(identity: INSTALLED)
    assert_equal ['Shaka start check: HEALTHY', 'Installation', 'Repository seam', 'Ruby', 'GitHub CLI',
                  'Repository access'], [report.lines.first.strip, *report.scan(/^\[\w+\] (.+?) —/).flatten]
    assert_includes report, '0.1.0 at '
    assert_includes report, 'revision 2363e217b603'
    assert_includes report, 'team settings committed in this checkout'
    refute_includes report, 'Machine alias'
    refute blocked
  end

  # A copied skill runs, so nothing else would tell the user it gets no update checks.
  def test_a_copied_skill_is_named_with_the_install_guide
    report, blocked = brief(identity: COPIED)
    assert_includes report, 'Shaka start check: DEGRADED'
    assert_includes report, '[DEGRADED] Installation — 0.1.0 at '
    assert_includes report, 'was not set up by the Shaka installer'
    assert_includes report, 'docs/getting-started.md#1-install-shaka'
    refute blocked
  end

  def test_unreadable_installation_metadata_fails_the_start_check
    report, blocked = brief(identity: -> { raise Shaka::Error, 'Installed package metadata is invalid.' })
    assert_includes report, '[FAILED] Installation — Installed package metadata is invalid.'
    assert blocked
  end

  def test_individual_settings_are_named_as_kept_out_of_git
    report, = brief(git: { 'rev-parse' => ['', false], 'status' => ["!! #{PATH}\n", true] })
    assert_includes report, '[HEALTHY] Repository seam — individual settings kept out of Git: '
  end

  def test_uncommitted_shared_settings_are_named
    report, = brief(git: { 'rev-parse' => ['', false], 'status' => ["?? #{PATH}\n", true] })
    assert_includes report, 'settings not committed yet: '
  end

  # A Git that cannot answer names no source, rather than calling the settings uncommitted.
  def test_settings_source_is_left_unnamed_when_git_fails
    report, = brief(git: { 'rev-parse' => ['', false], 'status' => ['', false] })
    assert_includes report, "[HEALTHY] Repository seam — #{PATH} loads and validates in this working tree"
  end

  def test_the_full_report_names_the_settings_source_too
    report, = doctor(runner: git_runner('rev-parse' => ['', false], 'status' => ["!! #{PATH}\n", true]))
    assert_includes report, '[HEALTHY] Repository seam — individual settings kept out of Git: '
  end

  def test_a_failed_basic_check_blocks_and_keeps_its_next_step
    report, blocked = brief(responses: { view: ['', 'gh auth login required', false] })
    assert_includes report, 'Shaka start check: FAILED'
    assert_includes report, '[FAILED] Repository access'
    assert_includes report, 'Next: Run doctor inside the checkout you publish from'
    assert blocked
  end

  def test_brief_refuses_reviewer_probes
    [%w[--brief --probe-reviewers], %w[--brief --installation-json], %w[--brief --host codex]].each do |arguments|
      assert_equal(1, silently { Shaka::Doctor.run(arguments) }, arguments.join(' '))
    end
  end

  private

  def brief(identity: INSTALLED, git: {}, responses: {})
    reader = identity.respond_to?(:call) ? identity : -> { identity }
    options = DEFAULTS.merge(runner: git_runner(git, responses))
    checks = Shaka::Doctor::Checks.new(root: File.expand_path('..', __dir__), host: 'claude-code',
                                       environment: options[:environment], system: stub_system(options))
    subject = Shaka::Doctor::Brief.new(checks: checks.brief, identity: reader)
    [subject.report, subject.blocked?]
  end

  # Git answers come from the test, and every other command falls through to the gh stub.
  def git_runner(git, responses = {})
    gh = stub_gh(responses)
    lambda do |argv, chdir = nil|
      next gh.call(argv, chdir) unless argv.first == 'git'

      output, answered = git.fetch(argv[1], ['', true])
      [output, '', answered]
    end
  end

  def silently
    original = [$stdout, $stderr]
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
  ensure
    $stdout, $stderr = original
  end
end
