# frozen_string_literal: true

require_relative 'test_helper'
require 'fileutils'
require 'rbconfig'
require 'shaka/update_check'

class UpdateCheckLaunchTest < Minitest::Test
  def test_trusted_wrapper_cannot_launch_a_candidate_interpreter
    Dir.mktmpdir('shaka-update-launch') do |directory|
      root, trusted, marker = prepare_wrapper(directory)
      with_path("#{root}/bin:#{trusted}:#{ENV.fetch('PATH')}") do
        Dir.chdir(root) { assert_safe_wrapper(marker) }
      end
    end
  end

  def test_missing_cli_does_not_launch_a_process
    Dir.mktmpdir do |root|
      with_path(root) do
        Dir.chdir(root) { assert_equal ['', '', false], Shaka::UpdateCheck.send(:capture, %w[gh api], Dir.tmpdir) }
      end
    end
  end

  private

  def with_path(path)
    original = ENV.fetch('PATH')
    ENV['PATH'] = path
    yield
  ensure
    ENV['PATH'] = original
  end

  def assert_safe_wrapper(marker)
    output, _error, ok = Shaka::UpdateCheck.send(:capture, %w[gh api], Dir.tmpdir)
    refute_path_exists marker
    assert ok, output
    assert_equal 'identical', JSON.parse(output).fetch('status')
  end

  def prepare_wrapper(directory)
    root = File.join(directory, 'candidate')
    trusted = File.join(directory, 'trusted')
    marker = File.join(directory, 'candidate-ran')
    FileUtils.mkdir_p([File.join(root, 'bin'), trusted])
    File.write(File.join(root, 'bin/ruby'), "#!/bin/sh\nprintf ran > '#{marker}'\nprintf '{}'\n")
    File.chmod(0o755, File.join(root, 'bin/ruby'))
    File.write(File.join(trusted, 'gh'), "#!/usr/bin/env ruby\nputs '{\"status\":\"identical\"}'\n")
    File.chmod(0o755, File.join(trusted, 'gh'))
    File.symlink(RbConfig.ruby, File.join(trusted, 'ruby'))
    [root, trusted, marker]
  end
end
