# frozen_string_literal: true

require_relative 'publication_test'

module CompanionResultFixtures
  HEAD = 'a' * 40
  EARLIER = 'b' * 40
  SUMMARY = '<summary>Companion skill results</summary>'
  ARTIFACT = 'https://github.com/example/demo/pull/89#issuecomment-123'

  private

  def render(results: nil, skills: [skill], head: HEAD)
    content = PublicationRegressionTest.new(:unused).description_content('skills_used' => skills)
    content['companion_results'] = results unless results.nil?
    pull = { 'head' => { 'sha' => head } } if head
    Shaka::Publication.description(content, nil, pull)
  end

  def skill(**changes)
    { 'name' => 'verify-flagship', 'source' => 'pstack', 'revision' => 'v1',
      'phase' => 'verification', 'contribution' => 'Ran the app',
      'evidence' => 'agent-reported', 'corroboration' => nil }.merge(changes)
  end

  def run_record(**changes)
    { 'skill' => 'verify-flagship', 'command' => 'verify-flagship drive slow', 'checked' => 'Rendered delay',
      'result' => 'Passed', 'not_covered' => 'Board interactions', 'commit' => HEAD, 'artifacts' => [ARTIFACT] }
      .merge(changes)
  end

  def assert_refused(entry, reason, **)
    error = assert_raises(Shaka::Error) { render(results: [entry], **) }
    assert_includes error.message, reason
  end
end

class PublicationCompanionResultsTest < Minitest::Test
  include CompanionResultFixtures

  def test_old_description_inputs_do_not_gain_a_section
    refute_includes render, SUMMARY
    refute_includes render(results: []), SUMMARY
  end

  def test_gathers_each_run_under_one_heading_and_marks_only_the_old_run_stale
    skills = [skill, skill('phase' => 'review')]
    description = render(skills:, results: [run_record, run_record('commit' => EARLIER)])

    assert_equal 1, description.scan(SUMMARY).size
    assert_equal 2, description.scan('**verify-flagship**').size
    assert_includes description, "**Commit:** `#{HEAD}`\n"
    assert_includes description, "**Commit:** `#{EARLIER}` · stale"
  end

  def test_shows_the_command_evidence_and_skill_revision_in_each_run
    description = render(results: [run_record])
    expected = ['Source:** pstack', 'Revision:** v1', 'Command:** `verify-flagship drive slow`',
                "Artifacts:** <#{ARTIFACT}>", 'What it checked:** Rendered delay', 'Result:** Passed',
                'Not covered:** Board interactions']
    expected.each { |field| assert_includes description, "- **#{field}" }
  end

  def test_republishing_recomputes_the_label_from_the_supplied_pull
    assert_includes render(results: [run_record], head: EARLIER), "**Commit:** `#{HEAD}` · stale"
    assert_includes render(results: [run_record], head: nil), "**Commit:** `#{HEAD}` · head unknown"
  end

  def test_matches_raw_skill_identity_and_escapes_html_in_rendered_text
    name = 'verify-flagship & <demo>'
    entry = run_record('skill' => name, 'source' => 'pstack & <checks>', 'revision' => '<v2>')
    records = [skill('name' => name, 'source' => 'pstack & <checks>', 'revision' => '<v2>'),
               skill('name' => name, 'source' => 'pstack & <checks>'),
               skill('name' => name, 'revision' => '<v2>')]
    description = render(results: [entry], skills: records)

    ['**verify-flagship &amp; &lt;demo&gt;**', 'Source:** pstack &amp; &lt;checks&gt;', 'Revision:** &lt;v2&gt;']
      .each { |escaped| assert_includes description, escaped }
  end

  def test_escapes_result_html_and_keeps_literal_command_text
    entry = run_record('result' => '**Passed** <b>with output</b> </details>',
                       'command' => 'printf "\\n" && cat evidence.txt', 'artifacts' => [])
    description = render(results: [entry])
    assert_includes description, '**Passed** &lt;b&gt;with output&lt;/b&gt; &lt;/details&gt;'
    assert_includes description, '`printf "\n" && cat evidence.txt`'
    refute_includes description, '**Artifacts:**'
  end

  def test_requires_a_discriminator_only_when_it_changes_the_matched_identity
    revised = skill('revision' => 'v2')
    other = skill('source' => 'project')
    assert_includes render(results: [run_record('source' => 'pstack')], skills: [skill, other]), '**Revision:** v1'
    assert_includes render(results: [run_record('revision' => 'v2')], skills: [skill, revised]), '**Revision:** v2'
    assert_refused(run_record, 'ambiguous', skills: [skill, other])
    assert_refused(run_record, 'ambiguous', skills: [skill, revised])
  end

  def test_refuses_invalid_keys_and_values
    assert_raises(Shaka::Error) { render(results: {}) }
    assert_refused(nil, 'fields')
    run_record.each_key { |key| assert_refused(run_record.except(key), 'fields') }
    assert_refused(run_record('output' => 'extra'), 'fields')
    assert_refused(run_record('commit' => HEAD[0, 7]), 'full SHA')
    assert_refused(run_record('source' => nil), 'source')
  end

  def test_refuses_results_without_a_matching_skill_record
    %w[skill source].each { |field| assert_refused(run_record(field => 'Verify-flagship'), 'matches no') }
    assert_refused(run_record, 'matches no', skills: nil)
  end

  def test_refuses_invalid_text_fields_and_command_delimiters
    invalid_text = ['', "first\nsecond", "first\rsecond", false]
    %w[checked result not_covered command].product(invalid_text).each do |field, value|
      assert_refused(run_record(field => value), field)
    end
    ['printf `uname`', 'echo </details>'].each { |command| assert_refused(run_record('command' => command), 'command') }
  end

  def test_only_accepts_http_artifact_urls
    [nil, 'https://github.com', ['mailto:person@example.org'], ['https:///missing-host'],
     ['https://example.org/with space'], ['https://example.org/<bad>'], [nil]].each do |artifacts|
      assert_refused(run_record('artifacts' => artifacts), 'artifacts')
    end
  end

  def test_refuses_local_paths_in_prose_and_commands
    assert_refused(run_record('command' => 'cat /Users/example/output.log'), 'local absolute path')
    assert_refused(run_record('command' => 'cc -I/Users/example/sdk -c demo.c'), 'local absolute path')
    assert_refused(run_record('command' => 'cc -I//Users/example/sdk -c demo.c'), 'local absolute path')
    assert_refused(run_record('command' => 'curl https://example.org/health;/Users/example/bin/check'),
                   'local absolute path')
    assert_refused(run_record('checked' => 'Read `/home/example/test`'), 'local absolute path')
    assert_refused(run_record('result' => 'Saved to /tmp/output.log'), 'local absolute path')
    assert_refused(run_record, 'local absolute path', skills: [skill('revision' => '/opt/example/skill')])
  end

  def test_refuses_local_paths_in_artifact_parameters
    %w[?path= #].each do |prefix|
      link = "https://example.org/capture#{prefix}%2FUsers%2Fexample%2Fpicture.png"
      assert_refused(run_record('artifacts' => [link]), 'local absolute path')
    end
  end

  def test_accepts_web_routes_and_relative_paths
    url = "https://example.org/teams/o'/home/(slow)/capture.png?name=%FF"
    entry = run_record('artifacts' => [url], 'checked' => 'Rendered `/slow` and `/users/1`; read spec/tmp/output.log')
    description = render(results: [entry])
    assert_includes description, 'Rendered `/slow`'
    assert_includes description, "<#{url}>"
  end
end
