# frozen_string_literal: true

require_relative 'private_delivery_helper'

class PrivateDeliverySettingsTest < Minitest::Test
  include PrivateDeliveryFixture

  def test_description_and_walkthrough_read_changed_private_prose_limits
    with_trial do
      publish_delivery
      update_private { |data| data['prose_limits'] = { 'max_sentence_words' => 2 } }
      publish_description(*evidence_files, exit_code: 1, error: 'limit 2')
      invoke('walkthrough', '--head', @ref, '--content-file', walkthrough_file, exit_code: 1, error: 'limit 2')
    end
  end

  def test_opening_reads_private_reviewer_enablement_and_prompt
    with_trial do
      prepare_private_opening
      assert_equal 'flagged', opening_status
      assert_includes File.read(File.join(@state, 'opening-prompt.txt')), 'Name the reader-facing subject.'
      update_private { |data| data['pr_description']['opening_check']['enabled'] = false }
      assert_equal 'disabled', opening_status
    end
  end

  def test_trusted_team_settings_win_after_adoption
    with_trial do
      adopt_team
      publish_delivery
      update_team_candidate
      assert_reviewer('anthropic/claude')
      assert_empty invoke('handoff')['owed']
      assert_equal 'seam', invoke('pr')['requiredChecksSource']
    end
  end

  private

  def opening_status = publish_description(*evidence_files, opening: true).dig('opening', 'status')

  def prepare_private_opening
    write_executable(@state, 'claude', fake_claude)
    path = '.agents/shaka/opening.md'
    File.write(File.join(@root, path), 'Name the reader-facing subject.')
    update_private { |data| data['pr_description']['opening_check'] = { 'replacement_prompt_file' => path } }
  end

  def adopt_team
    update_private { |data| data['merge']['required_checks'] = ['team-gate'] }
    git(@root, 'add', '-f', '.agents/shaka')
    commit(@root)
    @ref = git(@root, 'rev-parse', 'HEAD')
    alter_pull { |pull| pull['snapshot']['headRefOid'] = @ref }
  end

  def update_team_candidate
    path = Shaka::Configuration.worktree(root: @root).config_path
    data = YAML.safe_load_file(File.join(@root, path))
    data['merge'].delete('required_checks')
    data['review']['local_review_agents'] = [{ 'provider' => 'xai', 'model_family' => 'grok' }]
    File.write(File.join(@root, path), YAML.dump(data))
  end
end
