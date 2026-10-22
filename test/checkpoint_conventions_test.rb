# frozen_string_literal: true

require_relative 'support/post_implementation_fixture'

# The top-level checkpoint section and the conventional reviewers/checkpoint.md file.
class CheckpointConventionsTest < Minitest::Test
  include PostImplementationFixture

  RULES = '.agents/shaka/reviewers/checkpoint.md'
  REPLACEMENT = { 'post_implementation' => { 'prompt_file' => '.agents/codex-prompt.md' } }.freeze

  def test_top_level_checkpoint_section_reaches_the_runner
    @root_settings = { 'checkpoint' => { 'enabled' => false } }
    with_repository do |root, base, head, bin|
      result, status = run_checkpoint(root, base, head, bin)

      assert_predicate status, :success?, result.inspect
      assert_equal 'opted_out', result.fetch('status')
    end
  end

  def test_trusted_rules_follow_agents_files_and_name_their_source
    @rules = "Ask whether the PR removes a maintainer step.\n"
    with_repository do |root, base, head, bin|
      fake_checkpoint(bin, head)
      result, status = run_checkpoint(root, base, head, bin)
      prompt = assert_checkpoint_prompt(root).fetch('prompt')

      assert_predicate status, :success?, result.inspect
      assert_operator prompt.index('Trusted agent criteria'), :<, prompt.index('Ask whether the PR removes')
      assert_operator prompt.index('Ask whether the PR removes'), :<, prompt.index('BEGIN PACKET DATA')
      assert_equal "Shaka default + #{RULES}", result.fetch('prompt_source')
    end
  end

  def test_rules_add_to_a_replacement_prompt
    @rules = "Repository checkpoint rule\n"
    with_repository(REPLACEMENT) do |root, base, head, bin|
      fake_checkpoint(bin, head)
      _, status = run_checkpoint(root, base, head, bin)
      prompt = checkpoint_trace(root).fetch('prompt')

      assert_predicate status, :success?
      assert prompt.start_with?('Codex-only instructions')
      assert_includes prompt, 'Repository checkpoint rule'
      assert_includes prompt, 'the JSON report the checkpoint must return.'
    end
  end

  def test_empty_or_missing_rules_keep_the_built_in_prompt
    [nil, " \n"].each do |rules|
      @rules = rules
      with_repository do |root, base, head, bin|
        fake_checkpoint(bin, head)
        result, status = run_checkpoint(root, base, head, bin)

        assert_predicate status, :success?, result.inspect
        refute_includes checkpoint_trace(root).fetch('prompt'), 'TRUSTED CHECKPOINT RULES'
        assert_equal 'Shaka default', result.fetch('prompt_source')
      end
    end
  end

  def test_candidate_rules_never_reach_the_reviewer
    with_repository do |root, base, _head, bin|
      FileUtils.mkdir_p(File.join(root, File.dirname(RULES)))
      File.write(File.join(root, RULES), "Candidate-only rule\n")
      commit!(root, 'candidate rules')
      head = git!(root, 'rev-parse', 'HEAD').strip
      fake_checkpoint(bin, head)
      _, status = run_checkpoint(root, base, head, bin)

      assert_predicate status, :success?
      refute_includes checkpoint_trace(root).fetch('prompt'), 'TRUSTED CHECKPOINT RULES'
    end
  end

  private

  def seam(review) = super.merge(@root_settings || {})

  def write_trusted_files(root, review)
    super
    return unless @rules

    File.write(File.join(root, 'AGENTS.md'), "Trusted agent criteria\n")
    FileUtils.mkdir_p(File.join(root, File.dirname(RULES)))
    File.write(File.join(root, RULES), @rules)
  end
end

class CheckpointSectionSchemaTest < Minitest::Test
  include RepositoryConfigTestHelpers

  def test_checkpoint_section_folds_into_the_review_settings
    with_repository('checkpoint' => { 'reviewer' => 'anthropic/claude', 'effort' => 'high' }) do |root|
      config = Shaka::RepositoryConfig.load(root:)

      assert_equal({ 'reviewer' => 'anthropic/claude', 'effort' => 'high' }, config.review.fetch('post_implementation'))
    end
  end

  def test_checkpoint_section_and_old_key_together_are_refused
    settings = { 'checkpoint' => { 'enabled' => false },
                 'review' => review_policy('post_implementation' => { 'enabled' => true }) }
    with_repository(settings) do |root|
      error = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }

      assert_equal 'Use checkpoint or review.post_implementation, not both', error.message
    end
  end

  def test_checkpoint_errors_name_the_section
    with_repository('checkpoint' => { 'effort' => 'loud' }) do |root|
      error = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }

      assert_match(/\Acheckpoint\.effort must be/, error.message)
    end
  end
end
