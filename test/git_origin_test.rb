# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/git_origin'

class GitOriginTest < Minitest::Test
  def test_repository_name_from_https_and_scp_urls
    assert_equal 'agent-workflows', Shaka::GitOrigin.repository_name_from('https://github.com/acme/agent-workflows.git')
    assert_equal 'agent-workflows', Shaka::GitOrigin.repository_name_from('git@github.com:acme/agent-workflows.git')
    assert_equal 'shaka', Shaka::GitOrigin.repository_name_from('ssh://git@github.com/shakacode/shaka.git')
  end

  def test_identity_from_scp_url
    assert_equal 'acme/agent-workflows', Shaka::GitOrigin.identity('git@github.com:acme/agent-workflows.git')
  end
end
