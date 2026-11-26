# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'doctor_helper'

# The agent shows the start check in its first reply, so a user who has not set Shaka up reads why first.
class DoctorBriefSettingsMissingTest < Minitest::Test
  include DoctorHelper

  IDENTITY = { 'version' => '0.1.0', 'package_id' => 'p',
               'source' => { 'kind' => 'revision', 'revision' => '2363e217b6034b4b684ef88f2a29ddda458d870f' } }.freeze

  def test_a_repository_without_settings_opens_with_a_plain_sentence_and_the_next_step
    Dir.mktmpdir do |root|
      report, blocked = brief(root)
      first, second, third = report.lines.map(&:strip).reject(&:empty?)
      assert_equal Shaka::Doctor::Brief::NOT_SET_UP, first
      assert_includes second, 'Set up Shaka just for me'
      assert_includes second, 'team setup PR'
      assert_equal 'Shaka start check: FAILED', third
      assert blocked
    end
  end

  def test_a_repository_with_settings_opens_with_the_status_line
    report, = brief(File.expand_path('..', __dir__))
    assert report.start_with?('Shaka start check: ')
    refute_includes report, Shaka::Doctor::Brief::NOT_SET_UP
  end

  private

  def brief(root)
    runner = ->(argv, _chdir = nil) { [argv == %w[git version] ? 'git version 2.45.0' : '', '', true] }
    system = stub_system(DEFAULTS.merge(runner:))
    checks = Shaka::Doctor::Checks.new(root:, host: 'claude-code', environment: DEFAULTS[:environment], system:)
    subject = Shaka::Doctor::Brief.new(checks: checks.brief, identity: -> { IDENTITY },
                                       installation_state: Shaka::Doctor::InstallationState.new(system:))
    [subject.report, subject.blocked?]
  end
end
