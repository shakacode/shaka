# frozen_string_literal: true

require_relative 'install_scenario_support'

# What install status and update-check name: changed files, PR trials, and the registered installation.
class InstallStatusNamesTest < Minitest::Test
  include InstallScenarioSupport

  PACKAGE = "0.1.0-#{'a' * 64}-#{'b' * 64}".freeze

  # Git output arrives stripped, so an unstaged change on the first line once lost its first letter.
  def test_a_modified_first_file_keeps_its_whole_name
    root = default_install
    File.write(File.join(root, 'skills/shaka/SKILL.md'), 'edited')
    File.write(File.join(root, 'notes.txt'), 'draft')
    report = status(root)
    assert_equal 'B3', report['state']
    assert_includes report['detail'], 'uncommitted files: skills/shaka/SKILL.md, notes.txt'
  end

  # Trial storage also holds links and plans; only the prepared packages are trials.
  def test_only_prepared_packages_are_listed_as_trials
    default_install
    trials = File.join(@home, '.local/share/shaka/pr-trials')
    %W[installs/#{PACKAGE} links/123 plans/pr123-abc].each { |path| FileUtils.mkdir_p(File.join(trials, path)) }
    assert_equal [File.join(trials, 'installs', PACKAGE)], status(default_path)['inventory']['trials']
  end

  # A clone run beside a registered installation names that installation's helper instead of the installer.
  def test_update_check_from_an_unregistered_clone_names_the_registered_helper
    root = default_install
    clone = clone_to(File.join(@directory, 'second clone'))
    result = update_check(clone)
    assert_equal %w[uninstalled unregistered_copy], result.values_at('status', 'reason')
    assert_includes result['guidance'], "Run #{helper(root)} update-check"
  end

  # A host that loads the clone itself gets the general advice, as install --status gives no A9 redirect.
  def test_update_check_from_a_clone_the_host_links_use_names_no_other_helper
    default_install('--agent', 'claude')
    clone = clone_to(File.join(@directory, 'second clone'))
    link = File.join(@home, '.claude/skills/shaka')
    File.unlink(link)
    File.symlink(File.join(clone, 'skills/shaka'), link)
    result = update_check(clone)
    assert_equal ['uninstalled', nil], result.values_at('status', 'reason')
  end

  private

  # The fixture helper is a stub, so the clone runs this repository's real helper; that also proves its
  # requires load from a real helper path.
  def update_check(clone)
    FileUtils.rm_rf(File.join(clone, 'skills/shaka'))
    FileUtils.cp_r(File.expand_path('../skills/shaka', __dir__), File.join(clone, 'skills/shaka'))
    output, process = Open3.capture2e(environment.merge('SHAKA_RUBY' => RbConfig.ruby),
                                      File.join(clone, 'skills/shaka/scripts/shaka'), 'update-check')
    assert_predicate process, :success?, output
    JSON.parse(output)
  end
end
