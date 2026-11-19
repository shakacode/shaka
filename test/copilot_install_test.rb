# frozen_string_literal: true

require_relative 'official_install_support'

class CopilotInstallTest < Minitest::Test
  include OfficialInstallSupport

  def test_install_links_copilot_and_codex_to_the_same_source
    install_copilot
    [copilot, codex].each { |link| assert_equal File.realpath(@source), File.readlink(link) }
    assert_verified
  end

  def test_update_preserves_both_hosts
    install_copilot
    publish_updated_skill
    output, status = invoke('--update')
    assert_predicate status, :success?, output
    assert_equal 'updated skill', File.read(File.join(copilot, 'SKILL.md'))
    assert_equal File.readlink(codex), File.readlink(copilot)
    assert_verified
  end

  def test_verification_detects_a_missing_copilot_link
    install_copilot
    File.unlink(copilot)
    output, status = invoke('--verify')
    refute_predicate status, :success?
    assert_includes output, 'link is missing'
    assert_equal File.realpath(@source), File.readlink(codex)
  end

  def test_install_preserves_an_existing_skill_directory
    FileUtils.mkdir_p(copilot)
    File.write(File.join(copilot, 'SKILL.md'), 'personal skill')
    output, status = invoke('--directory', @root, '--repository', @remote, '--agent', 'copilot')
    refute_predicate status, :success?
    assert_equal 'personal skill', File.read(File.join(copilot, 'SKILL.md'))
    assert_includes output, 'Refusing existing destination:'
  end

  private

  def copilot = File.join(@home, '.copilot/skills/shaka')
  def codex = File.join(@home, '.agents/skills/shaka')

  def install_copilot
    output, status = invoke('--directory', @root, '--repository', @remote, '--agent', 'copilot', '--agent', 'codex')
    assert_predicate status, :success?, output
  end

  def publish_updated_skill
    File.write(File.join(@source, 'SKILL.md'), 'updated skill')
    commit_source
    git('-C', @root, 'push', '-q', 'origin', 'main')
  end

  def assert_verified
    output, status = invoke('--verify')
    assert_predicate status, :success?, output
  end
end
