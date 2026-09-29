# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/workflow_version'

# Links only commits whose recorded source is shakacode/shaka, so a fork-only commit never 404s.
class WorkflowVersionSourceTest < Minitest::Test
  VERSION = Shaka::VERSION
  SHA = 'a' * 40

  def result(commit, upstream:)
    Shaka::WorkflowVersion::Result.new(version: VERSION, commit:, modified: false, upstream:)
  end

  def source(repository)
    { 'version' => VERSION, 'source' => { 'kind' => 'revision', 'revision' => SHA, 'repository' => repository } }
  end

  def test_an_installation_from_shakacode_shaka_is_upstream
    %w[https://github.com/shakacode/shaka git@github.com:shakacode/shaka.git
       https://github.com/shakacode/shaka.git].each do |repository|
      assert_equal result(SHA, upstream: true), Shaka::WorkflowVersion.current(identity: source(repository)), repository
    end
  end

  def test_an_installation_from_a_fork_or_unknown_source_is_not_upstream
    [nil, 'https://github.com/someone/shaka', 'git@github.com:shakacode/shaka-fork.git'].each do |repository|
      assert_equal result(SHA, upstream: false), Shaka::WorkflowVersion.current(identity: source(repository)),
                   repository.inspect
    end
  end
end
