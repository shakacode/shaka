# frozen_string_literal: true

require_relative 'install_scenario_support'
require_relative 'install_row_scenarios'

# Through the installed helper: install --update retires the answer it made stale, and the next
# check that day repeats its own saved answer without asking GitHub.
class UpdateCheckAfterInstallTest < Minitest::Test
  include InstallScenarioSupport
  include UnlistedRowScenarios

  def test_install_update_retires_the_saved_answer_and_the_next_check_lasts_the_day
    root = update_after_saved_drift
    hook, = run_helper(root, 'update-check', '--session-start', github: "touch #{ran}")
    assert_empty hook
    assert_equal 'current', update_check(root, github: "echo '#{CURRENT}'").fetch('status')
    repeated = update_check(root, github: "touch #{ran}")
    assert_equal 'current', repeated.fetch('status')
    assert repeated.key?('checked_at'), repeated.inspect
    refute_path_exists ran
  end

  private

  # A manual pull saves a drift answer, then install --update records the pull.
  def update_after_saved_drift
    root = full_skill_install
    pull(root)
    assert_equal 'drift', update_check(root, github: "echo '#{CURRENT}'").fetch('status')
    # The checkout's origin names GitHub, so its fetch reads the fixture remote instead.
    git('-C', root, 'config', "url.#{@remote}.insteadOf", OFFICIAL)
    run_install(root, '--update')
    root
  end
end
