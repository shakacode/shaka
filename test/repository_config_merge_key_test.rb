# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require 'shaka/repository_config'

# A merge key or a tagged key would let a later entry replace a value the way a duplicate key does.
class RepositoryConfigMergeKeyTest < Minitest::Test
  include RepositoryConfigTestHelpers

  def test_rejects_a_nested_merge_key_that_would_override_a_value
    with_repository do |root|
      path = File.join(root, '.agents/shaka/config.yml')
      source = File.read(path)
      File.write(path, source.sub("  preference: auto\n", "  preference: auto\n  <<: {preference: ask}\n"))
      refute_equal source, File.read(path)

      error = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }

      assert_includes error.message, 'YAML merge keys (<<) are not allowed'
    end
  end

  def test_rejects_a_top_level_merge_key
    with_repository do |root|
      path = File.join(root, '.agents/shaka/config.yml')
      File.write(path, "#{File.read(path)}<<: {merge: {preference: ask}}\n")

      error = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }

      assert_includes error.message, 'YAML merge keys (<<) are not allowed'
    end
  end

  # Psych applies each of these as a merge.
  def test_rejects_a_quoted_or_string_tagged_merge_key
    ['"<<": {base_branch: trunk}', '!ruby/string <<: {base_branch: trunk}'].each do |line|
      with_repository do |root|
        path = File.join(root, '.agents/shaka/config.yml')
        File.write(path, "#{File.read(path)}#{line}\n")

        error = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }

        assert_includes error.message, 'YAML merge keys (<<) are not allowed', line
      end
    end
  end

  # Psych decodes !!binary PDw= to << and applies the merge.
  def test_rejects_a_tagged_key_that_could_hide_a_merge
    with_repository do |root|
      path = File.join(root, '.agents/shaka/config.yml')
      File.write(path, "#{File.read(path)}!!binary PDw=: {base_branch: trunk}\n")

      error = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }

      assert_includes error.message, 'YAML keys must not carry tags'
    end
  end
end
