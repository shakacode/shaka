# frozen_string_literal: true

# Scenarios for #683 rows that `install --status` does not name: each reaches the row the way a
# person would and checks what Shaka says there.
module UnlistedRowScenarios
  RETIRED = /retained copy|official main|\bupstream\b/i
  CURRENT = '{"status":"identical","ahead_by":0,"oldest":null}'

  private

  # A second bin/install meets the first installation's links and names the person's choice.
  def build_row_c2
    output, process = second_install
    refute_predicate process, :success?
    assert_includes output, "owned by the installation at #{File.realpath(default_path)}"
    assert_includes output, 'Next: a person must decide which installation to keep'
  end

  def build_row_d2
    root = full_skill_install
    result = update_check(root, github: "echo '#{CURRENT}'")
    assert_equal 'current', result.fetch('status'), result.inspect
  end

  def build_row_d3
    root = full_skill_install
    pull(root)
    result = update_check(root, github: "echo '#{CURRENT}'")
    assert_equal 'drift', result.fetch('status'), result.inspect
    assert_includes result.fetch('guidance'), "is at #{git('-C', root, 'rev-parse', '--short=7', 'HEAD').strip}"
  end

  # A chat whose agent never runs update-check still hears the saved answer when it starts.
  def build_row_d4
    root = full_skill_install
    pull(root)
    drift = update_check(root, github: "echo '#{CURRENT}'")
    output, process = run_helper(root, 'update-check', '--session-start', github: "touch #{ran}")
    assert_predicate process, :success?, output
    assert_equal "Shaka update check: #{drift.fetch('guidance')}\n", output
    refute_path_exists ran
  end

  def build_row_d5
    root = full_skill_install
    { 'request_failed' => 'echo "error connecting to api.github.com" >&2; exit 1',
      'signed_out' => 'echo "To get started with GitHub CLI, please run:  gh auth login" >&2; exit 4' }
      .each do |reason, github|
        result = update_check(root, github:)
        assert_equal ['unknown', reason], result.values_at('status', 'reason'), result.inspect
        assert_includes result.fetch('guidance'), 'retry `update-check` later'
      end
  end

  # Installer output only; update-check guidance still names 'official main' (#687).
  def build_row_e2
    root = clone_to(default_path)
    git('-C', root, 'remote', 'set-url', 'origin', InstallScenarioSupport::OFFICIAL)
    outputs = [succeeded(install_from(root))]
    pull(root)
    outputs << succeeded(run_status(root))
    refusal, process = second_install
    refute_predicate process, :success?
    assert_includes refusal, 'Refusing existing destination'
    (outputs << refusal).each { |output| refute_match RETIRED, output }
  end

  # A repository with only the settings layout from before 1.0 has no settings: seam check stops and
  # names the file it needs. It does not name the old layout or a command that converts it.
  def build_row_e3
    repository = File.join(@directory, 'old layout')
    FileUtils.mkdir_p(File.join(repository, '.agents/bin'))
    File.write(File.join(repository, '.agents/agent-workflow.yml'), "version: 1\n")
    git('init', '-q', repository)
    output, process = Open3.capture2e(environment, *SHAKA_COMMAND, 'seam', 'check', '--root', repository, '--local')
    refute_predicate process, :success?
    assert_includes output, 'Cannot find .agents/shaka/config.yml'
  end

  def second_install
    default_install unless File.directory?(default_path)
    install_from(clone_to(File.join(@directory, 'second clone')), '--repository', @remote)
  end

  def install_from(root, *)
    Open3.capture2e(environment, RbConfig.ruby, File.join(root, 'bin/install'), '--directory', root, *)
  end

  def succeeded((output, process))
    assert_predicate process, :success?, output
    output
  end

  # The fixture helper is a stub, so update-check needs the real skill pushed to the fixture remote.
  def full_skill_install
    replace_fixture_with_full_skill
    git('init', '-q', '-b', 'main', @root)
    git('-C', @root, 'remote', 'add', 'origin', @remote)
    commit_source
    git('-C', @root, 'push', '-qf', 'origin', 'main')
    default_install
  end

  def update_check(root, github:)
    output, process = run_helper(root, 'update-check', github:)
    assert_predicate process, :success?, output
    JSON.parse(output.lines.last)
  end

  # Runs the installed helper from HOME, outside every repository, with a stand-in `gh`.
  def run_helper(root, *, github:)
    bin = File.join(@directory, 'bin')
    FileUtils.mkdir_p(bin)
    File.write(File.join(bin, 'gh'), "#!/bin/sh\n#{github}\n")
    File.chmod(0o755, File.join(bin, 'gh'))
    Open3.capture2e(environment.merge('PATH' => "#{bin}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH')}"),
                    File.join(root, 'skills/shaka/scripts/shaka'), *, chdir: @home)
  end

  def ran = File.join(@directory, 'ran')
end
