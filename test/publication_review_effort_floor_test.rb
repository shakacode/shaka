# frozen_string_literal: true

require_relative 'publication_test'
require_relative 'github_helper'
require 'shaka/publication/feature_guard'

# #690 and #694 changed the workflow every task loads, and #704 changed Ruby, yet each rated
# its review effort 1, which the scale reserves for docs a reader can trust from the description.
class PublicationReviewEffortFloorTest < Minitest::Test
  include GitHubHelper

  WORKFLOW = 'skills/shaka/config/workflow.yml'

  def floor(*paths) = Shaka::ReviewEffortFloor.for(paths)

  def render(paths, effort)
    intent = INTENT.merge('review_effort' => effort)
    content = PublicationRegressionTest.new(name).description_content('intent' => intent)
    floor = paths && Shaka::ReviewEffortFloor.for(paths, Shaka::ReviewEffortFloor.defaults)
    Shaka::Publication.description(content, nil, nil, Shaka::PublicationSettings.new(review_effort_floor: floor))
  end

  def test_docs_images_and_readmes_have_no_floor
    assert_equal 1, floor('docs/settings.md', 'README.md', 'docs/images/flow.svg')['level']
  end

  # People asked for changes on agent-instruction PRs and on no code-only PR (#785).
  def test_agent_instructions_have_a_floor_of_three_and_code_of_two
    { WORKFLOW => 3, 'AGENTS.md' => 3, 'nested/CLAUDE.md' => 3 }.each do |path, level|
      assert_equal({ 'level' => level, 'reason' => 'changes agent instructions', 'path' => path },
                   floor(path).slice('level', 'reason', 'path'))
    end
    %w[lib/report.rb test/report_test.rb].each do |path|
      assert_equal({ 'level' => 2, 'reason' => 'changes code or configuration', 'path' => path },
                   floor(path).slice('level', 'reason', 'path'))
    end
  end

  def test_trust_merge_authentication_and_release_paths_have_a_floor_of_four
    ['.github/workflows/ci.yml', 'skills/shaka/lib/shaka/merge.rb',
     'lib/oauth/callback.rb', 'script/releases.sh', 'CODEOWNERS', 'docs/CODEOWNERS', 'src/AuthService.ts',
     'app/MergeQueue.java', 'lib/OAuthCallback.kt', 'lib/HTTPAuth.rb'].each do |path|
      assert_equal 4, floor(path)['level'], path
    end
  end

  def test_shaka_configuration_has_a_floor_of_five
    assert_equal 5, floor('.agents/shaka/config.yml')['level']
  end

  # except removes a file from its own floor only: a guide about merging under skills/ escapes the
  # trust floor's Markdown exception yet still matches the agent-instructions floor.
  def test_except_removes_a_file_from_its_own_floor_only
    result = floor('skills/shaka/references/merge.md')

    assert_equal [3, 'changes agent instructions'], result.values_at('level', 'reason')
  end

  # A word inside a longer name, such as auth in author, is not that word, and a guide
  # about merging is still a guide.
  def test_words_match_whole_name_tokens_outside_docs
    assert_equal 2, floor('lib/author.rb')['level']
    assert_equal 1, floor('docs/merge-preference.md', 'release-notes.md')['level']
  end

  def test_the_highest_floor_wins_and_names_its_path
    result = floor('docs/a.md', WORKFLOW, '.github/workflows/ci.yml')

    assert_equal [4, '.github/workflows/ci.yml'], result.values_at('level', 'path')
  end

  def test_a_rating_below_the_floor_is_refused_with_the_floor_and_its_reason
    error = assert_raises(Shaka::Error) { render([WORKFLOW], 1) }

    assert_includes error.message, "review_effort 1 is below this PR's floor of 3: it changes agent instructions " \
                                   "(`#{WORKFLOW}`). Rate it 3 or higher."
  end

  def test_a_rating_at_or_above_the_floor_renders_the_floor_reason
    assert_includes render([WORKFLOW], 4),
                    '**Review effort:** 4 of 5, threshold: read every line and run it yourself. ' \
                    "Floor 3: changes agent instructions (`#{WORKFLOW}`)."
  end

  # A filename is PR-controlled; a backtick, newline, or comment marker could reshape the description.
  def test_a_filename_outside_the_plain_set_is_withheld
    ["lib/x`\n\n## Injected.rb", 'lib/<!-- shaka:end -->.rb'].each do |path|
      rendered = render([path], 2)
      assert_includes rendered, 'Floor 2: changes code or configuration (a file whose name is withheld).'
      refute_includes rendered, 'Injected'
      refute_includes rendered, '<!-- shaka:end -->.rb'
    end
  end

  # A repository's floors can be stricter, so falling back to the shipped ones must show.
  def test_unread_repository_floors_are_named_in_the_line
    content = PublicationRegressionTest.new(name).description_content
    floor = Shaka::ReviewEffortFloor.for(['docs/a.md'])
    rendered = Shaka::Publication.description(content, nil, nil,
                                              Shaka::PublicationSettings.new(review_effort_floor: floor))

    assert_includes rendered, "Shaka's shipped floors applied because this repository's settings were not read."
  end

  def test_no_floor_text_without_a_floor_or_without_a_pull_request
    refute_includes render(['docs/a.md'], 1), 'Floor'
    refute_includes render(nil, 1), 'Floor'
  end

  # A rename keeps the risk of the file it came from.
  def test_the_publication_guard_returns_both_names_of_a_rename_for_every_flow
    file = { 'filename' => 'docs/old-merge.md', 'previous_filename' => 'lib/merge.rb' }
    assert_equal 4, floor(file['filename'], file['previous_filename'])['level']
    %w[setup migration].each do |flow|
      paths = Shaka::FeaturePublication.check(github: client(response([file])), pull: { 'changed_files' => 1 }, flow:)
      assert_equal %w[docs/old-merge.md lib/merge.rb], paths
    end
  end
end
