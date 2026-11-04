# frozen_string_literal: true

require_relative 'install_scenario_support'
require_relative 'install_scenario_builders'
require_relative 'install_row_scenarios'
require_relative '../skills/shaka/lib/shaka/install/status_states'

# Builds every install state `install --status` names, in a temporary HOME, and checks the state,
# where it was found, and the one next step. A state without a scenario here fails, and so does
# any other #683 row without one.
class InstallScenariosTest < Minitest::Test
  include InstallScenarioSupport
  include HealthyInstallScenarios
  include BrokenInstallScenarios
  include UnlistedRowScenarios

  # Every row of the #683 install matrix. A row that is not a status state needs build_row_<id>.
  MATRIX = %w[A1 A2 A3 A4 A5 A6 A8 A9 B1 B2 B3 B4 B5 B6 B7 B8 B9 B10 C1 C2 C3 C5
              D1 D2 D3 D4 D5 D6 E1 E2 E3].freeze
  AFTER_1_0 = { 'D1' => 'versioned install folders (#682)', 'D6' => 'opt-in scheduled updates (#682)' }.freeze

  (MATRIX - Shaka::Install::StatusStates::STATES.keys).each do |id|
    define_method("test_row_#{id}") do
      skip "#{id} waits for #{AFTER_1_0[id]} after 1.0" if AFTER_1_0.key?(id)
      builder = "build_row_#{id.downcase}"
      flunk "No scenario for #683 row #{id}; add #{builder}" unless respond_to?(builder, true)
      send(builder)
    end
  end

  Shaka::Install::StatusStates::STATES.each_key do |id|
    define_method("test_state_#{id}") do
      builder = "build_#{id.downcase}"
      flunk "No install scenario for state #{id}; add #{builder}" unless respond_to?(builder, true)
      expected = send(builder)
      report = status(expected.fetch(:from))
      assert_equal id, report['state'], JSON.pretty_generate(report)
      assert_equal canonical(expected.fetch(:location)), canonical(report['location'])
      assert_one_next_step(report, expected[:next])
    end
  end

  def test_problems_are_named_in_fix_order
    root = default_install
    pull(root)
    File.write(File.join(root, 'notes.txt'), 'draft')
    report = status(root)
    assert_equal 'B3', report['state']
    assert_includes report['findings'].map { |item| item['id'] }, 'B1'
  end

  def test_an_unsafe_checkout_gets_no_git_reads
    root = default_install
    File.write(File.join(root, 'notes.txt'), 'draft')
    git('-C', root, 'config', 'core.fsmonitor', "touch #{File.join(@directory, 'ran')}")
    File.chmod(0o775, root)
    report = status(root)
    assert_equal(['B10'], report['findings'].select { |item| item['location'] == File.realpath(root) }.map { it['id'] })
    refute_path_exists File.join(@directory, 'ran')
  end

  # Development in the checkout breaks nothing, so a missing link is still the first thing to fix.
  def test_development_ranks_after_a_missing_link
    root = default_install
    git('-C', root, 'worktree', 'add', '-q', File.join(@directory, 'feature'))
    File.unlink(File.join(@home, '.agents/skills/shaka'))
    report = status(root)
    assert_equal ['B9', nil], report.values_at('state', 'next_command')
    assert_includes report['decision'], 'Move the development out first'
    assert_includes report['findings'].map { |item| item['id'] }, 'C3'
  end

  def test_status_changes_nothing
    root = default_install
    pull(root)
    before = snapshot
    output, process = run_status(root)
    assert_predicate process, :success?, output
    assert_includes output, 'Shaka install state: B1'
    assert_equal before, snapshot
  end
end
