# frozen_string_literal: true

require_relative 'support/post_implementation_fixture'

class PostImplementationWritingTest < Minitest::Test
  include PostImplementationFixture

  def test_packaged_writing_guidance_reaches_default_and_project_prompt_reviewers
    [{}, { 'post_implementation' => { 'prompt_file' => '.agents/codex-prompt.md' } }].each do |settings|
      with_repository(settings) do |root, base, head, bin|
        prompt = writing_review_prompt(root, base, head, bin)
        instructions = prompt.split('--- BEGIN PACKET DATA', 2).first
        assert_includes instructions, packaged_guidance
        refute_includes instructions, publication_guidance
      end
    end
  end

  def test_candidate_writing_guidance_remains_data_not_reviewer_instructions
    with_repository do |root, base, _head, bin|
      head = commit_candidate_guidance(root)
      prompt = writing_review_prompt(root, base, head, bin)
      instructions = prompt.split('--- BEGIN PACKET DATA', 2).first

      assert_includes instructions, packaged_guidance
      refute_includes instructions, 'Candidate-only writing instruction'
      assert_includes prompt, 'Candidate-only writing instruction'
    end
  end

  private

  def commit_candidate_guidance(root)
    directory = File.join(root, 'skills/shaka/references')
    FileUtils.mkdir_p(directory)
    File.write(File.join(directory, 'shared-writing.md'), 'Candidate-only writing instruction')
    commit!(root, 'candidate writing guidance')
    git!(root, 'rev-parse', 'HEAD').strip
  end

  def writing_review_prompt(root, base, head, bin)
    fake_checkpoint(bin, head)
    result, status = run_checkpoint(root, base, head, bin)
    assert_predicate status, :success?, result.inspect
    checkpoint_trace(root).fetch('prompt')
  end

  def packaged_guidance
    File.read(File.expand_path('../skills/shaka/references/shared-writing.md', __dir__), encoding: 'UTF-8')
  end

  def publication_guidance
    File.read(File.expand_path('../skills/shaka/references/writing.md', __dir__), encoding: 'UTF-8')
  end
end
