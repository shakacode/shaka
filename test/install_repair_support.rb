# frozen_string_literal: true

require_relative 'install_scenario_support'

# Checks one `install --repair` run: the state it reaches, the files it leaves, and a second run.
module InstallRepairSupport
  private

  def repair(root) = Open3.capture2e(environment, RbConfig.ruby, File.join(root, 'bin/install'), '--repair')

  # Repair reaches the expected state, deletes nothing but the records it renames, and a second run
  # changes nothing.
  def assert_repaired(root, state, final: nil, retired: [])
    assert_equal state, status(root)['state']
    before = files
    output, process = repair(root)
    assert_equal final.nil?, process.success?, output
    assert_includes output, "Repairing #{state}"
    report = status(root)
    final ? assert_equal(final, report['state']) : assert_equal('ok', report['severity'], output)
    assert_nothing_deleted(before, retired)
    assert_second_run_changes_nothing(root)
  end

  def assert_nothing_deleted(before, retired)
    records = retired.map { |root| File.join(root, '.git/shaka-install.json') }
    assert_equal records.sort, (before - files).sort
    records.each { |record| refute_empty Dir.glob(File.join(File.dirname(record), 'shaka-install.retired-*.json')) }
  end

  def assert_second_run_changes_nothing(root)
    before = snapshot
    output, = repair(root)
    assert_includes output, 'Nothing to repair.'
    assert_equal before, snapshot
  end

  # Every file outside Git's own storage, plus the install records inside it, in HOME and the fixture.
  def files
    [@home, @root].flat_map { |base| Dir.glob('**/*', File::FNM_DOTMATCH, base:).map { |entry| File.join(base, entry) } }
                  .reject { |path| path.include?('/.git/') && !path.end_with?('/.git/shaka-install.json') }
  end
end
