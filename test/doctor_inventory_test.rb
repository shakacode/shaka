# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'doctor_helper'
require_relative 'repository_fixture'

class DoctorInventoryTest < Minitest::Test
  include DoctorHelper
  include RepositoryConfigTestHelpers

  def test_inventory_survives_missing_repository_setup_and_gives_installation_guidance
    Dir.mktmpdir do |root|
      report, blocked = doctor(root:, executable: ->(*) {})

      assert blocked
      %w[codex claude grok].each { |command| assert_includes report, "#{command} missing from PATH" }
      assert_includes report, 'https://github.com/openai/codex'
      assert_includes report, 'https://code.claude.com/docs/en/setup'
      assert_includes report, 'https://docs.x.ai/build/overview'
      assert_includes report, 'codex login'
      assert_includes report, 'configuration unavailable'
    end
  end

  def test_inventory_includes_optional_clis_and_the_selected_executable_path
    review = review_policy('local_review_agents' => [{ 'provider' => 'openai', 'model_family' => 'codex' }])
    with_repository('review' => review) do |root|
      report, = doctor(root:, executable: ->(name, *) { name == 'codex' ? '/tools/codex' : nil })

      assert_includes report, '/tools/codex'
      assert_includes report, 'grok missing from PATH (optional)'
      assert_includes report, 'Sign-in, quota, and CLI compatibility are unverified'
    end
  end

  def test_an_unsafe_cli_does_not_hide_the_other_inventory_entries
    lookup = lambda do |name, *_args|
      raise Shaka::Error, 'unsafe wrapper' if name == 'codex'

      "/tools/#{name}"
    end
    report, = doctor(executable: lookup)

    assert_includes report, 'codex not checked: unsafe wrapper'
    assert_includes report, '/tools/claude'
    assert_includes report, '/tools/grok'
  end

  def test_an_invalid_configuration_does_not_hide_the_inventory
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, '.agents'))
      File.write(File.join(root, '.agents/agent-workflow.yml'), "version: invalid\n")
      report, blocked = doctor(root:, executable: ->(name, *) { "/tools/#{name}" })

      assert blocked
      %w[codex claude grok].each { |command| assert_includes report, "/tools/#{command}" }
    end
  end

  def test_missing_optional_tools_do_not_degrade_a_repository_using_fresh_host_review
    review = review_policy
    review.delete('local_review_agents')
    with_repository('review' => review) do |root|
      report, blocked = doctor(root:, executable: ->(*) {})

      assert_includes report, '[HEALTHY] Reviewer CLIs'
      assert_includes report, 'codex missing from PATH (optional)'
      refute blocked
    end
  end
end
