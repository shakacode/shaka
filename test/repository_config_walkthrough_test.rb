# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require 'shaka/repository_config'

class RepositoryConfigWalkthroughTest < Minitest::Test
  include RepositoryConfigTestHelpers

  def test_walkthroughs_are_published_on_request_by_default
    with_repository({}) do |root|
      assert_equal({ 'publish' => 'on_request' }, Shaka::RepositoryConfig.load(root:).walkthrough)
    end
  end

  def test_a_repository_can_publish_one_on_every_pr
    with_repository('walkthrough' => { 'publish' => 'always' }) do |root|
      assert_equal 'always', Shaka::RepositoryConfig.load(root:).to_h.dig('walkthrough', 'publish')
    end
  end

  def test_rejects_an_unknown_value_or_key
    [{ 'publish' => 'sometimes' }, { 'notes' => true }, 'always'].each do |walkthrough|
      with_repository('walkthrough' => walkthrough) do |root|
        error = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }
        assert_includes error.message, 'walkthrough'
      end
    end
  end

  # Without readable trusted settings, a gate keeps the earlier rule that every PR needs a walkthrough.
  def test_a_gate_without_trusted_settings_requires_a_walkthrough
    assert_equal 'always', Shaka::RepositoryConfig::WalkthroughSchema.gate(nil)
    assert_equal 'on_request', Shaka::RepositoryConfig::WalkthroughSchema.publish(nil)
  end
end
