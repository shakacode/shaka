# frozen_string_literal: true

require_relative 'review_prompt_file_test'
require_relative 'support/post_implementation_fixture'
require 'shaka/configuration/settings_preview'

class SettingsPreviewReviewTest < Minitest::Test
  include ReviewPromptFileFixture

  def test_preview_prompt_model_and_round_cap_reach_the_reviewer
    with_repository({ 'replacement_prompt_file' => '.agents/review-prompt.md' }) do |root, base, _head, bin|
      head = preview_review(root)
      fake_codex(bin, head)
      Shaka::Configuration::SettingsPreview.new(root:).start(head)
      ledger = File.join(bin, 'ledger.json')
      output, error, status = run_review(root, base, head, bin, '--ledger', ledger)
      assert_predicate status, :success?, "#{output} #{error}"
      assert_equal 20, JSON.parse(File.read(ledger))['local_max_rounds']
      assert_preview_inputs(root, JSON.parse(output))
    end
  end

  private

  def preview_review(root)
    path = File.join(root, '.agents/agent-workflow.yml')
    data = YAML.safe_load_file(path)
    data['review']['local_max_rounds'] = 20
    data['review']['local_review_agents'] = [{ 'provider' => 'openai', 'model_family' => 'codex',
                                               'model' => 'preview-model' }]
    File.write(path, YAML.dump(data))
    commit!(root, 'preview settings')
    git!(root, 'rev-parse', 'HEAD').strip
  end

  def assert_preview_inputs(root, result)
    assert_equal 'Local settings preview (private source)', result['prompt_source']
    trace = JSON.parse(File.read(File.join(root, 'trace.json')))
    assert_includes trace['args'].each_cons(2).to_a, ['-m', 'preview-model']
    assert_includes trace['prompt'].split('SUPPORTING SOURCE DATA').first, 'Candidate instructions'
  end

  def fake_codex(bin, head)
    write_executable(bin, 'codex', <<~RUBY)
      #!/usr/bin/env ruby
      require 'json'
      File.write(ENV.fetch('REVIEW_TRACE'), JSON.generate(prompt: STDIN.read, args: ARGV))
      File.write(ARGV.fetch(ARGV.index('-o') + 1), "REVIEWED #{head} BY openai/codex EFFORT UNKNOWN FINDINGS 0\n")
    RUBY
  end
end

class SettingsPreviewCheckpointTest < Minitest::Test
  include PostImplementationFixture

  def test_a_preview_that_sets_enabled_is_refused
    with_repository do |root, _base, _head, _bin|
      head = preview_checkpoint(root)
      error = assert_raises(Shaka::Error) { Shaka::Configuration::SettingsPreview.new(root:).start(head) }

      assert_includes error.message, 'checkpoint.enabled was removed'
    end
  end

  private

  def preview_checkpoint(root)
    path = File.join(root, '.agents/agent-workflow.yml')
    data = YAML.safe_load_file(path)
    data['checkpoint'] = { 'enabled' => false, 'model' => 'preview-model',
                           'replacement_prompt_file' => '.agents/private-checkpoint.md' }
    File.write(File.join(root, '.agents/private-checkpoint.md'), 'Assess the intended outcome.')
    File.write(path, YAML.dump(data))
    commit!(root, 'preview checkpoint')
    git!(root, 'rev-parse', 'HEAD').strip
  end
end
