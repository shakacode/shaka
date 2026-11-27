# frozen_string_literal: true

require_relative 'publication_companion_results_test'

class PublicationCompanionResultOutcomesTest < Minitest::Test
  include CompanionResultFixtures

  FIX = 'c' * 40

  def test_a_run_without_outcome_fields_renders_as_before
    description = render(results: [run_record])
    ['**Outcome:**', '**Cleared paths:**', '**Manual check:**'].each { |label| refute_includes description, label }
  end

  def test_shows_each_outcome_with_a_fixed_label
    { 'no_findings' => 'No findings', 'findings_not_applied' => 'Findings not applied' }.each do |outcome, label|
      assert_includes render(results: [run_record('outcome' => outcome)]), "- **Outcome:** #{label}\n"
    end
  end

  def test_names_the_commits_a_finding_caused
    entry = run_record('outcome' => 'changed_code', 'caused_commits' => [FIX, EARLIER])
    assert_includes render(results: [entry]), "- **Outcome:** Changed code · `#{FIX}`, `#{EARLIER}`\n"
  end

  def test_refuses_an_outcome_that_disagrees_with_its_commits
    assert_refused(run_record('outcome' => 'fixed'), 'outcome')
    assert_refused(run_record('outcome' => nil), 'outcome')
    assert_refused(run_record('outcome' => 'changed_code'), 'caused_commits')
    assert_refused(run_record('outcome' => 'changed_code', 'caused_commits' => []), 'caused_commits')
    assert_refused(run_record('outcome' => 'no_findings', 'caused_commits' => [FIX]), 'caused_commits')
    assert_refused(run_record('caused_commits' => [FIX]), 'caused_commits')
    assert_refused(run_record('outcome' => 'no_findings', 'caused_commits' => []), 'caused_commits')
    assert_refused(run_record('caused_commits' => []), 'caused_commits')
  end

  def test_refuses_caused_commits_that_are_not_full_shas
    [FIX[0, 7], nil, "#{FIX}\n"].each do |sha|
      assert_refused(run_record('outcome' => 'changed_code', 'caused_commits' => [sha]), 'caused_commits')
    end
    assert_refused(run_record('outcome' => 'changed_code', 'caused_commits' => FIX), 'caused_commits')
  end

  def test_lists_cleared_paths_as_code
    entry = run_record('cleared_paths' => ['.github/workflows/validate.yml', 'docs/**/*.md'])
    assert_includes render(results: [entry]),
                    "- **Cleared paths:** `.github/workflows/validate.yml`, `docs/**/*.md`\n"
    refute_includes render(results: [run_record('cleared_paths' => [])]), '**Cleared paths:**'
  end

  def test_refuses_cleared_paths_outside_the_repository_or_unsafe_to_render
    ['/etc/hosts', '../other/file.rb', 'lib/../../x', 'a`b', "a\nb", '', ' ', 'docs/</details>', nil,
     'C:\\Users\\x', '~/notes.md', '~other/notes.md', 'file:///Users/example/x', 'https://example.org/a',
     'docs /Users/example/x', ' /custom-root/report.txt ', 'docs/a.md '].each do |path|
      assert_refused(run_record('cleared_paths' => [path]), 'cleared_paths')
    end
    assert_refused(run_record('cleared_paths' => 'docs/a.md'), 'cleared_paths')
  end

  def test_a_manual_check_renders_as_prose_not_a_command
    entry = run_record('manual' => true, 'command' => 'Read the <gemspec> and its callers')
    description = render(results: [entry])
    assert_includes description, '- **Manual check:** Read the &lt;gemspec&gt; and its callers'
    refute_includes description, '**Command:**'
    assert_includes render(results: [run_record('manual' => false)]), '**Command:** `verify-flagship drive slow`'
  end

  def test_refuses_a_manual_flag_that_is_not_a_boolean_and_local_paths_in_manual_text
    assert_refused(run_record('manual' => 'yes'), 'manual')
    assert_refused(run_record('manual' => true, 'command' => 'Read /Users/example/notes'), 'local absolute path')
    assert_refused(run_record('manual' => true, 'command' => "one\ntwo"), 'command')
  end
end
