# frozen_string_literal: true

require_relative 'test_helper'
require 'fileutils'
require 'stringio'
require 'shaka/trial/prepare'

class TrialPrepareTest < Minitest::Test
  URL = 'https://github.com/shakacode/shaka/pull/359'

  def setup
    @tmp = Dir.mktmpdir('shaka-trial-test-')
    @source = File.join(@tmp, 'source')
    @project = File.join(@tmp, 'project')
    @directory = File.join(@tmp, 'trials')
    FileUtils.mkdir_p([File.join(@source, 'skills/shaka/lib/shaka'), @project])
    create_source
    git('init', '-q')
    git('add', '.')
    git('-c', 'user.name=Fixture', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'Candidate')
    @head = git('rev-parse', 'HEAD').strip
  end

  def teardown
    FileUtils.remove_entry(@tmp)
  end

  def test_prepares_an_exact_copy_without_activating_the_normal_skill
    first = prepare
    assert_equal @head, first['candidate_head']
    assert_equal 'Candidate skill', File.read(first['skill'])
    assert_includes first['startup_prompt'], @head
    assert_includes first['startup_prompt'], @project
  end

  def test_reuses_the_same_pinned_package_and_survives_source_removal
    first = prepare
    assert_equal first['skill'], prepare['skill']
    FileUtils.remove_entry(@source)
    assert_equal 'Candidate skill', File.read(first['skill'])
  end

  def test_head_mismatch_creates_no_package
    assert_raises(Shaka::Error) { prepare(head: 'a' * 40) }
    refute_path_exists File.join(@directory, 'installs')
  end

  def test_refuses_a_destination_inside_the_target_project
    @directory = File.join(@project, 'trial')
    assert_raises(Shaka::Error) { prepare }
    refute_path_exists @directory
  end

  def test_refuses_private_or_foreign_candidate_metadata
    assert_raises(Shaka::Error) { prepare(private: true) }
    assert_raises(Shaka::Error) { prepare(repository: 'elsewhere/shaka') }
  end

  private

  def git(*) = Open3.capture3(TEST_GIT, '-C', @source, *)[0]

  def create_source
    File.write(File.join(@source, 'skills/shaka/SKILL.md'), 'Candidate skill')
    File.write(File.join(@source, 'skills/shaka/lib/shaka/version.rb'), "module Shaka\n VERSION = '0.1.0'\nend\n")
    FileUtils.mkdir_p([File.join(@source, 'skills/shaka/scripts'), File.join(@source, 'bin')])
    helper = File.join(@source, 'skills/shaka/scripts/shaka')
    File.write(helper, "#!/bin/sh\nexit 1\n")
    File.chmod(0o755, helper)
    File.write(File.join(@source, 'bin/install'), "raise 'Candidate installer must not execute'\n")
  end

  def prepare(**metadata)
    result = nil
    output, = capture_io do
      result = Shaka::Trial::Prepare.new(URL, root: @project, directory: @directory,
                                              github: github(**metadata), fetcher: fetcher).run
    end
    assert_empty output
    refute_path_exists File.join(@directory, 'links')
    result
  end

  def github(head: @head, private: false, repository: 'shakacode/shaka')
    github = Object.new
    github.define_singleton_method(:api) do |*|
      { 'head' => { 'sha' => head }, 'state' => 'open',
        'base' => { 'repo' => { 'full_name' => repository, 'private' => private } } }
    end
    github
  end

  def fetcher
    lambda do |target, _number|
      system(TEST_GIT, 'clone', '-q', @source, target, exception: true)
      system(TEST_GIT, '-C', target, 'remote', 'set-url', 'origin', 'https://github.com/shakacode/shaka.git',
             exception: true)
    end
  end
end
