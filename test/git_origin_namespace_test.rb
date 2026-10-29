# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/git_origin'

class GitOriginNamespaceTest < Minitest::Test
  def test_nested_namespace_identity_and_leaf_name_survive_each_transport
    %w[
      https://gitlab.com/group/subgroup/project.git
      ssh://git@gitlab.com/group/subgroup/project.git
      git@gitlab.com:group/subgroup/project.git
    ].each do |origin|
      assert_equal 'group/subgroup/project', Shaka::GitOrigin.identity(origin)
      assert_equal 'project', Shaka::GitOrigin.repository_name_from(origin)
    end
  end

  def test_canonical_url_keeps_nested_namespace_host_and_nondefault_port
    assert_equal 'https://gitlab.example:8443/group/subgroup/project',
                 Shaka::GitOrigin.canonical_url('https://user:SECRET@gitlab.example:8443/group/subgroup/project.git')
    assert_equal 'ssh://gitlab.example:2222/group/subgroup/project',
                 Shaka::GitOrigin.canonical_url('ssh://git@gitlab.example:2222/group/subgroup/project.git')
    assert_equal 'ssh://gitlab.example/group/subgroup/project',
                 Shaka::GitOrigin.canonical_url('git@gitlab.example:group/subgroup/project.git')
  end

  def test_any_number_of_namespace_components_preserves_the_full_identity
    origin = 'https://gitlab.example/group/subgroup/team/project.git/?token=SECRET#ignored'

    assert_equal 'group/subgroup/team/project', Shaka::GitOrigin.identity(origin)
    assert_equal 'https://gitlab.example/group/subgroup/team/project', Shaka::GitOrigin.canonical_url(origin)
  end

  def test_empty_or_dot_path_components_are_not_repository_identities
    %w[group//project group/./project group/../project group/subgroup/. group/subgroup/.. project].each do |path|
      %W[https://gitlab.example/#{path} git@gitlab.example:#{path}].each do |origin|
        assert_raises(Shaka::Error, origin) { Shaka::GitOrigin.identity(origin) }
      end
    end
  end
end
