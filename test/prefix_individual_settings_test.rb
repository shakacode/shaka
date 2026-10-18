# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'configuration_layout_fixture'
require 'shaka/prefix'

class PrefixIndividualSettingsTest < Minitest::Test
  include ConfigurationLayoutFixture

  def test_complete_individual_settings_supply_the_prefix
    with_individual_settings('repo_prefix' => 'CPF') do |root, ref|
      assert_equal({ 'prefix' => 'CPF', 'source' => 'individual' }, prefix(root, ref))
    end
  end

  def test_complete_individual_settings_without_a_prefix_use_the_fallback
    with_individual_settings do |root, ref|
      assert_equal 'fallback', prefix(root, ref).fetch('source')
    end
  end

  def test_partial_individual_settings_keep_the_fallback
    with_individual_settings('repo_prefix' => 'CPF') do |root, ref|
      File.delete(File.join(root, '.agents/shaka/bin/test'))
      assert_equal 'fallback', prefix(root, ref).fetch('source')
    end
  end

  private

  def prefix(root, ref) = Shaka::Prefix.new(root:, ref:).call

  def with_individual_settings(extra = {})
    Dir.mktmpdir('shaka-prefix-individual') do |root|
      git!(root, 'init', '--quiet')
      File.write(File.join(root, 'README.md'), "project\n")
      git!(root, 'add', 'README.md')
      git!(root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '--quiet', '-m', 'project')
      ref = Open3.capture2('git', '-C', root, 'rev-parse', 'HEAD').first.strip
      FileUtils.mkdir_p(File.join(root, '.agents/shaka/bin'))
      create_new_commands(root)
      File.write(File.join(root, '.agents/shaka/config.yml'), YAML.dump(config.merge(extra)))
      yield root, ref
    end
  end

  def git!(root, *)
    output, status = Open3.capture2e('git', '-C', root, *)
    raise output unless status.success?
  end
end
