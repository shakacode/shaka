# frozen_string_literal: true

require_relative 'support/post_implementation_fixture'

# Trusted commits that hold checkpoint custom instructions at chosen paths.
module CheckpointInstructionsFixture
  include PostImplementationFixture

  RULES = '.agents/shaka/instructions/checkpoint.md'
  REPLACEMENT = { 'checkpoint' => { 'replacement_prompt_file' => '.agents/codex-prompt.md' } }.freeze
  NAMED = '.agents/named-rules.md'
  PRECEDENCE = File.expand_path('../skills/shaka/config/checkpoint-rules-precedence.md', __dir__)
  NAMED_SETTINGS = { 'checkpoint' => { 'custom_instructions_file' => NAMED } }.freeze

  private

  def seam(review) = super.merge(@root_settings || {})

  # The default folder is a symlink to another folder in the repository.
  def write_linked_rules(root)
    FileUtils.mkdir_p(File.join(root, '.agents/shared-instructions'))
    File.write(File.join(root, '.agents/shared-instructions/checkpoint.md'), @linked)
    FileUtils.mkdir_p(File.join(root, '.agents/shaka'))
    File.symlink('../shared-instructions', File.join(root, '.agents/shaka/instructions'))
  end

  def write_trusted_files(root, review)
    super
    File.write(File.join(root, NAMED), @named) if @named
    write_linked_rules(root) if @linked
    return unless @rules

    File.write(File.join(root, 'AGENTS.md'), "Trusted agent criteria\n")
    FileUtils.mkdir_p(File.join(root, File.dirname(RULES)))
    File.write(File.join(root, RULES), @rules)
  end
end

# The top-level checkpoint section and checkpoint.custom_instructions_file, with its default path.
class CheckpointConventionsTest < Minitest::Test
  include CheckpointInstructionsFixture

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
      assert_includes prompt, File.read(PRECEDENCE).strip
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
end

# A named custom instructions file, and the default one under a symlinked folder.
class CheckpointNamedInstructionsTest < Minitest::Test
  include CheckpointInstructionsFixture

  def test_a_named_file_is_added_and_the_default_one_is_ignored
    @rules = "Default-location rule\n"
    @named = "Named rule\n"
    with_repository(NAMED_SETTINGS) do |root, base, head, bin|
      fake_checkpoint(bin, head)
      result, status = run_checkpoint(root, base, head, bin)
      assert_predicate status, :success?, result.inspect
      assert_equal "Shaka default + #{NAMED}", result.fetch('prompt_source')
      assert_includes checkpoint_trace(root).fetch('prompt'), 'Named rule'
      refute_includes checkpoint_trace(root).fetch('prompt'), 'Default-location rule'
    end
  end

  def test_a_default_file_under_a_symlinked_folder_reaches_the_reviewer
    @linked = "Linked-folder rule\n"
    with_repository do |root, base, head, bin|
      fake_checkpoint(bin, head)
      _, status = run_checkpoint(root, base, head, bin)

      assert_predicate status, :success?
      assert_includes checkpoint_trace(root).fetch('prompt'), 'Linked-folder rule'
    end
  end

  def test_a_named_file_that_is_missing_fails_the_checkpoint
    with_repository(NAMED_SETTINGS) do |root, base, head, bin|
      fake_checkpoint(bin, head)
      result, status = run_checkpoint(root, base, head, bin)

      refute_predicate status, :success?
      assert_includes result.fetch('reason'), NAMED
    end
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

  def test_the_old_review_key_names_its_new_section
    with_repository('review' => review_policy('post_implementation' => { 'enabled' => true })) do |root|
      error = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }

      assert error.message.start_with?('review.post_implementation moved to the top-level checkpoint section.')
    end
  end

  def test_checkpoint_errors_name_the_section
    with_repository('checkpoint' => { 'effort' => 'loud' }) do |root|
      error = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }

      assert_match(/\Acheckpoint\.effort must be/, error.message)
    end
  end
end
