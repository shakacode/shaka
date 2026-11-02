# frozen_string_literal: true

require_relative 'publication_test'

# A docs edit set a whole code PR to a rating that said to review every line (#1001), so the line now
# names the files that set the floor.
class PublicationHumanReviewTest < Minitest::Test
  WORKFLOW = 'skills/shaka/config/workflow.yml'

  def render(paths, effort, rules = Shaka::ReviewEffortFloor.defaults)
    intent = INTENT.merge('review_effort' => effort)
    content = PublicationRegressionTest.new(name).description_content('intent' => intent)
    floor = paths && Shaka::ReviewEffortFloor.for(paths, rules)
    Shaka::Publication.description(content, nil, nil, Shaka::PublicationSettings.new(review_effort_floor: floor))
  end

  def test_a_rating_above_the_floor_keeps_its_own_reading_and_names_the_floor_files
    assert_includes render([WORKFLOW], 4),
                    '**Human review:** 4 of 5, read the riskiest files closely. ' \
                    "Floor 3: `#{WORKFLOW}` (changes agent instructions)."
  end

  # One docs file must not read as a request to study the whole PR (#1001).
  def test_a_rating_at_the_floor_names_only_the_files_that_set_it
    rendered = render(['.agents/shaka/config.yml', 'lib/a.rb', 'test/a_test.rb'], 5)

    assert_includes rendered, '**Human review:** 5 of 5. Read `.agents/shaka/config.yml` (changes Shaka\'s ' \
                              'repository configuration). 2 other files set a lower floor.'
    refute_includes rendered, 'every line'
  end

  def test_files_at_one_level_are_grouped_by_the_floor_that_set_them
    rules = [{ 'level' => 5, 'reason' => 'changes settings', 'paths' => ['.agents/**/*'] },
             { 'level' => 5, 'reason' => 'changes guides', 'paths' => ['docs/**/*'] },
             { 'level' => 2, 'reason' => 'changes code', 'paths' => ['**/*'] }]
    rendered = render(['docs/a.md', '.agents/x.yml', 'lib/a.rb'], 5, rules)

    assert_includes rendered, 'Read `.agents/x.yml` (changes settings), `docs/a.md` (changes guides). ' \
                              '1 other file sets a lower floor.'
  end

  def test_every_file_at_the_floor_leaves_out_the_other_files_sentence
    refute_includes render([WORKFLOW], 3), 'lower floor'
  end

  def test_a_long_list_stops_at_five_names_and_counts_the_rest
    paths = (1..8).map { |number| "lib/a#{number}.rb" }
    rendered = render(paths, 2)

    assert_includes rendered, '**Human review:** 2 of 5. Skim `lib/a1.rb`, `lib/a2.rb`, `lib/a3.rb`, `lib/a4.rb`, ' \
                              '`lib/a5.rb` and 3 more (changes code or configuration).'
  end

  # A filename is PR-controlled; a backtick, newline, or comment marker could reshape the description.
  def test_a_filename_outside_the_plain_set_is_withheld
    ["lib/x`\n\n## Injected.rb", 'lib/<!-- shaka:end -->.rb'].each do |path|
      rendered = render([path], 2)
      assert_includes rendered, 'Skim a file whose name is withheld (changes code or configuration).'
      refute_includes rendered, 'Injected'
      refute_includes rendered, '<!-- shaka:end -->.rb'
    end
  end

  def test_no_floor_text_without_a_floor_or_without_a_pull_request
    assert_includes render(['docs/a.md'], 1), '**Human review:** 1 of 5, the description should be enough.'
    refute_includes render(['docs/a.md'], 1), 'Floor'
    refute_includes render(nil, 1), 'Floor'
  end
end
