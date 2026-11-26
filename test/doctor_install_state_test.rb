# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'doctor_helper'

# Doctor names the install state and the one next step `install --status` chose.
class DoctorInstallStateTest < Minitest::Test
  include DoctorHelper

  def test_a_healthy_install_names_its_state
    report, = doctor
    assert_includes report, '[HEALTHY] Install state — A1 Default install, one host at /home/.local/share/shaka/source'
  end

  def test_an_orphan_record_names_the_next_command
    orphan = lambda do
      { 'state' => 'C1', 'title' => 'Orphan installation record', 'severity' => 'attention',
        'location' => '/home/.local/share/shaka/source', 'detail' => 'this record owns nothing',
        'next_command' => 'mv record record.retired' }
    end
    report, blocked = doctor(installation_status: orphan)
    assert_includes report, '[DEGRADED] Install state — C1 Orphan installation record'
    assert_includes report, 'Next: Run mv record record.retired.'
    refute blocked
  end

  def test_a_status_failure_is_reported_not_raised
    report, = doctor(installation_status: -> { raise ArgumentError, 'Installation Git operation failed' })
    assert_includes report, 'install --status could not run: Installation Git operation failed'
  end

  def test_a_brief_report_names_the_recovery_command_after_a_manual_pull
    report, blocked = brief('B1', 'Manual pull of the registered branch', 'next_command' => 'shaka install --update')
    assert_includes report, 'Shaka start check: DEGRADED'
    assert_includes report, 'revision 2363e217b603'
    assert_includes report, '[DEGRADED] Install state — B1 Manual pull of the registered branch'
    assert_includes report, 'Next: Run shaka install --update.'
    refute blocked
  end

  def test_a_brief_report_names_the_recovery_decision_for_linked_worktrees
    step = { 'decision' => 'Move development to a separate clone' }
    report, blocked = brief('C3', 'Source checkout hosts worktrees', step)
    assert_includes report, '[DEGRADED] Install state — C3 Source checkout'
    assert_includes report, 'Next: Decide: Move development to a separate clone.'
    refute blocked
  end

  private

  def brief(id, title, step)
    status = -> { INSTALLED_STATE.call.merge('state' => id, 'title' => title, 'severity' => 'attention', **step) }
    system = stub_system(DEFAULTS.merge(installation_status: status))
    state = Shaka::Doctor::InstallationState.new(system:)
    identity = -> { { 'version' => '1.0.0', 'source' => { 'kind' => 'revision', 'revision' => '2363e217b6034b' } } }
    subject = Shaka::Doctor::Brief.new(checks: [], installation_state: state, identity:)
    [subject.report, subject.blocked?]
  end
end
