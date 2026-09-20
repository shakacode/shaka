# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/git_origin'

class GitOriginTest < Minitest::Test
  def test_repository_name_from_https_and_scp_urls
    assert_equal 'agent-workflows', Shaka::GitOrigin.repository_name_from('https://github.com/acme/agent-workflows.git')
    assert_equal 'agent-workflows', Shaka::GitOrigin.repository_name_from('git@github.com:acme/agent-workflows.git')
    assert_equal 'shaka', Shaka::GitOrigin.repository_name_from('ssh://git@github.com/shakacode/shaka.git')
    assert_equal 'beta', Shaka::GitOrigin.repository_name_from('https://user:token@github.com/acme/beta.git')
  end

  def test_canonical_url_rewrites_only_the_github_host
    assert_equal 'https://github.com/acme/alpha',
                 Shaka::GitOrigin.canonical_url('git@github.com:acme/alpha.git')
    assert_equal 'https://notgithub.com/acme/beta',
                 Shaka::GitOrigin.canonical_url('https://notgithub.com/acme/beta.git')
    assert_equal 'https://gist.github.com/acme/beta',
                 Shaka::GitOrigin.canonical_url('https://gist.github.com/acme/beta.git')
  end

  def test_canonical_url_strips_userinfo_on_every_host
    assert_equal 'https://ghe.example/acme/repo',
                 Shaka::GitOrigin.canonical_url('https://user:token@ghe.example/acme/repo.git')
    assert_equal 'https://github.com/acme/beta',
                 Shaka::GitOrigin.canonical_url('https://user:token@github.com/acme/beta.git')
    assert_equal 'https://ghe.example:8443/acme/repo',
                 Shaka::GitOrigin.canonical_url('https://user:token@ghe.example:8443/acme/repo.git')
  end

  def test_canonical_url_strips_ssh_userinfo
    assert_equal 'ssh://ghe.example/acme/repo',
                 Shaka::GitOrigin.canonical_url('ssh://user:token@ghe.example/acme/repo.git')
    assert_equal 'ssh://ghe.example:2222/acme/repo',
                 Shaka::GitOrigin.canonical_url('ssh://user:token@ghe.example:2222/acme/repo.git')
    assert_equal 'ssh://ghe.example/acme/repo',
                 Shaka::GitOrigin.canonical_url('ssh://git@ghe.example/acme/repo.git')
  end

  def test_identity_from_urls_with_an_authority_port
    assert_equal 'acme/repo', Shaka::GitOrigin.identity('https://ghe.example:8443/acme/repo.git')
    assert_equal 'acme/repo', Shaka::GitOrigin.identity('ssh://git@ghe.example:2222/acme/repo.git')
  end

  def test_identity_from_scp_url
    assert_equal 'acme/agent-workflows', Shaka::GitOrigin.identity('git@github.com:acme/agent-workflows.git')
  end
end
