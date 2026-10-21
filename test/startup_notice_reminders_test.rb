# frozen_string_literal: true

require_relative 'startup_notice_support'

# A first task in an unconfigured repository starts with the setup choice, and a machine that never ran
# doctor hears about it, without relying on the agent to remember either.
class StartupNoticeRemindersTest < Minitest::Test
  include StartupNoticeSupport

  def setup
    super
    # An unregistered checkout has no update answers, so only these reminders can show.
    @helper_root = checkout('development', registered: false)
    @repository = File.join(@directory, 'project')
    FileUtils.mkdir_p(File.join(@repository, '.git'))
    @repository = File.realpath(@repository)
  end

  def test_a_repository_without_settings_names_the_file_and_both_setups_once_a_day
    line = reminder
    assert_includes line, "#{@repository} has no Shaka settings (.agents/shaka/config.yml)"
    assert_includes line, 'Unless the user already chose, ask for a private trial in this clone or team setup'
    assert_includes line, 'getting-started.md#2-choose-individual-or-team-setup'
    assert_nil reminder(now: NOW + 3600)
    assert_match(/no Shaka settings/, reminder(now: NOW + Shaka::UpdateCheck::Cache::SECONDS + 1))
  end

  # A private trial keeps its settings ignored in the working tree, so it counts like team settings.
  def test_settings_in_the_working_tree_in_either_layout_are_quiet
    %w[.agents/shaka/config.yml .agents/agent-workflow.yml].each do |contract|
      path = File.join(@repository, contract)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "version: 1\n")
      assert_nil reminder, contract
      FileUtils.rm_rf(File.join(@repository, '.agents'))
    end
  end

  def test_each_repository_gets_its_own_daily_reminder
    other = File.join(@directory, 'other')
    FileUtils.mkdir_p(File.join(other, '.git'))
    reminder
    assert_match(/no Shaka settings/, reminder(repository: File.realpath(other)))
  end

  def test_a_machine_where_doctor_never_ran_is_reminded_once_a_day
    FileUtils.rm_f(Shaka::StartupNotice::Marks.doctor_path(@home))
    assert_match(/\AShaka doctor has not run on this machine\. Run .*development.* doctor --brief/,
                 reminder(repository: nil))
    assert_nil reminder(repository: nil, now: NOW + 60)
    Shaka::StartupNotice::Marks.doctor_ran(env: {}, home: @home, now: NOW)
    assert_nil reminder(repository: nil, now: NOW + Shaka::UpdateCheck::Cache::SECONDS + 1)
  end

  # Doctor reports the settings itself, and seam is the setup already under way.
  def test_doctor_and_setup_get_neither_reminder
    FileUtils.rm_f(Shaka::StartupNotice::Marks.doctor_path(@home))
    %w[doctor seam].each { |command| assert_nil reminder(command:), command }
  end

  def test_an_update_notice_comes_first_and_the_reminder_waits_for_the_next_call
    remember('available', at: NOW)
    assert_equal 'available guidance', reminder(root: @root)
    assert_match(/no Shaka settings/, reminder(root: @root, now: NOW + 60))
  end

  def test_a_reminder_that_cannot_be_recorded_is_not_shown
    path = Shaka::StartupNotice::Marks.notices_path(@home)
    File.chmod(0o500, File.dirname(path))
    assert_nil reminder
  ensure
    File.chmod(0o700, File.dirname(path))
  end

  def test_the_repository_comes_from_root_or_the_nearest_checkout_above_the_directory
    nested = File.join(@repository, 'lib/deep')
    FileUtils.mkdir_p(nested)
    assert_equal @repository, Shaka::StartupNotice.repository(['seam', '--root', nested])
    assert_equal @repository, Shaka::StartupNotice.repository(["--root=#{@repository}"])
    assert_equal @repository, Dir.chdir(nested) { Shaka::StartupNotice.repository(['workflow']) }
    assert_nil Shaka::StartupNotice.repository(['--root', File.join(@home)])
  end

  # Doctor writes its mark outside every repository, and nothing while notices are off.
  def test_doctor_records_its_run_unless_notices_are_off
    mark = Shaka::StartupNotice::Marks.doctor_path(@home)
    FileUtils.rm_f(mark)
    path = failing_gh
    run_doctor('HOME' => @home, 'PATH' => path, 'SHAKA_NOTICES' => 'off')
    refute_path_exists mark
    run_doctor('HOME' => @home, 'PATH' => path, 'SHAKA_NOTICES' => nil)
    assert_path_exists mark
  end

  private

  def reminder(repository: @repository, command: 'pr', now: NOW, root: @helper_root)
    Shaka::StartupNotice.new(home: @home, root:, now:, repository:, command:).line
  end

  # No request leaves the machine: gh answers every call with a failure.
  def failing_gh
    stub = File.join(@directory, 'stub')
    FileUtils.mkdir_p(stub)
    File.write(File.join(stub, 'gh'), "#!/bin/sh\nexit 1\n")
    File.chmod(0o755, File.join(stub, 'gh'))
    "#{stub}:#{ENV.fetch('PATH')}"
  end

  def run_doctor(env)
    _output, error, = Open3.capture3(env, COMMAND, 'doctor', '--brief', '--root', @repository)
    refute_includes error, 'not recorded'
  end
end
