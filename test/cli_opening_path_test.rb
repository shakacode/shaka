# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require_relative 'cli_opening_check_fakes'
require_relative '../skills/shaka/lib/shaka/opening_publication'
require 'json'
require 'rbconfig'

class CliOpeningPathTest < Minitest::Test
  include RepositoryConfigTestHelpers
  include CliOpeningCheckFakes

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  ROOT = File.expand_path('..', __dir__)
  SUMMARY = 'Pull requests explain the outcome first.'

  def test_candidate_git_on_path_is_ignored_before_publication
    with_repository do |root|
      commit(root)
      Dir.mktmpdir { |dir| assert_candidate_git_rejected(dir, root) }
    end
  end

  def test_direct_opening_publication_filters_candidate_git
    with_repository do |root|
      commit(root)
      Dir.mktmpdir { |dir| assert_direct_opening_safe(dir, root) }
    end
  end

  private

  def assert_candidate_git_rejected(dir, root)
    with_candidate_git(dir, root) do |trace|
      output, error, status = run_description(dir, root:, ref: true)
      assert_predicate status, :success?, error
      assert_equal 'host_check', JSON.parse(output).dig('opening', 'status')
      refute_path_exists trace
      assert_path_exists File.join(dir, 'published.md')
    end
  end

  def assert_direct_opening_safe(dir, root)
    with_candidate_git_link(dir, root) do |trace|
      result = Shaka::OpeningPublication.new(root:, ref: 'HEAD').call(SUMMARY)
      assert_equal 'host_check', result.fetch('status')
      refute_path_exists trace
    end
  end

  def with_candidate_git(dir, root)
    Dir.mkdir(bin = File.join(root, 'candidate-bin'))
    trace = File.join(dir, 'candidate-git-called')
    write_executable(bin, 'git', "File.write(#{trace.inspect}, '')")
    with_candidate_path(bin) { yield trace }
  end

  def with_candidate_git_link(dir, root)
    Dir.mkdir(bin = File.join(root, 'candidate-bin'))
    trace = File.join(dir, 'candidate-git-called')
    write_executable(bin, 'git', "File.write(#{trace.inspect}, '')")
    Dir.mkdir(external = File.join(dir, 'external-bin'))
    File.symlink(File.join(bin, 'git'), File.join(external, 'git'))
    with_candidate_path(external) { yield trace }
  end

  def with_candidate_path(bin)
    original = ENV.fetch('PATH')
    ENV['PATH'] = "#{bin}::#{original}"
    yield
  ensure
    ENV['PATH'] = original
  end
end
