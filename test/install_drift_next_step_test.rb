# frozen_string_literal: true

require_relative 'install_scenario_support'

# A checkout that moved off its recorded revision gets the step install --status gives, or a person's decision.
class InstallDriftNextStepTest < Minitest::Test
  include InstallScenarioSupport
  include InstallRefusalSteps

  def test_local_commits_get_the_step_that_keeps_them_on_a_branch
    root = default_install
    commit(root, 'local change')
    step = refused(root, '--verify')
    assert_includes step, 'reset --keep'
    run_step(step)
    installer(root, '--verify')
    refute_empty git('-C', root, 'for-each-ref', '--format=%(refname:short)', 'refs/heads/kept-*').strip
  end

  # git branch refuses a kept name already in use, so a kept branch moved elsewhere needs a person.
  def test_local_commits_with_an_occupied_kept_branch_need_a_person
    root = default_install
    commit(root, 'local change')
    name = "kept-#{git('-C', root, 'rev-parse', '--short', 'HEAD').strip}"
    git('-C', root, 'branch', name, 'HEAD~1')
    assert_includes refusal(root, '--verify'), 'Next: a person must decide where to keep these commits, because ' \
                                               "branch #{name}"
    report = status(root)
    assert_equal 'B2', report['state']
    assert_nil report['next_command']
  end

  # A checkout reset behind its record catches up with a fast-forward.
  def test_a_checkout_behind_its_record_fast_forwards
    root = default_install
    pull(root)
    head = record_head(root)
    git('-C', root, 'reset', '-q', '--hard', 'HEAD~1')
    step = refused(root, '--verify')
    assert_includes step, 'merge --ff-only'
    run_step(step)
    assert_equal head, git('-C', root, 'rev-parse', 'HEAD').strip
  end

  # When origin's history was rewritten, which history to keep is a person's choice, as status says.
  def test_a_rewritten_origin_needs_a_person
    root = default_install
    commit(@root, 'rewritten', amend: true)
    git('-C', @root, 'push', '--force', '-q', 'origin', 'main')
    git('-C', root, 'fetch', '-q', @remote, '+main:refs/remotes/origin/main')
    git('-C', root, 'reset', '-q', '--hard', 'origin/main')
    output = refusal(root, '--verify')
    refute_includes output, 'reset --keep'
    assert_includes output, 'Next: a person must decide which revision main should use'
  end

  private

  # Points the install record at HEAD and returns it.
  def record_head(root)
    head = git('-C', root, 'rev-parse', 'HEAD').strip
    record = File.join(root, '.git/shaka-install.json')
    File.write(record, JSON.generate(JSON.parse(File.read(record)).merge('revision' => head)))
    head
  end
end
