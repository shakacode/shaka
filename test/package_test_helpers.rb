# frozen_string_literal: true

require_relative 'test_helper'
require 'fileutils'
require 'json'
require 'rbconfig'
require 'yaml'
require 'bundler'
require 'rubygems/package'

module PackageTestHelpers
  ROOT = File.expand_path('..', __dir__)

  def setup
    @directory = Dir.mktmpdir('workflows-package')
    @home = File.join(@directory, 'gem home')
    @environment = { 'GEM_HOME' => @home, 'GEM_PATH' => @home }
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  private

  def install_gem
    archive = File.join(@directory, 'consumer.gem')
    run_gem('build', 'shaka.gemspec', '--output', archive, chdir: ROOT)
    run_gem('install', '--local', '--no-document', archive)
  end

  def with_consumer_seam
    Dir.mktmpdir('shaka-consumer-seam') do |root|
      FileUtils.mkdir_p(File.join(root, '.agents/bin'))
      %w[setup validate test].each do |name|
        path = File.join(root, '.agents/bin', name)
        File.write(path, "#!/bin/sh\nexit 0\n")
        File.chmod(0o755, path)
      end
      write_consumer_yaml(root, consumer_seam)
      yield root
    end
  end

  def write_consumer_yaml(root, data)
    File.write(File.join(root, '.agents/agent-workflow.yml'), YAML.dump(data))
  end

  def consumer_seam
    {
      'version' => 1,
      'review' => { 'required' => 'none' },
      'merge' => { 'preference' => 'ask' }
    }
  end

  def capture_installed(*)
    Bundler.with_unbundled_env do
      Open3.capture3(@environment, File.join(@home, 'bin', 'shaka'), *)
    end
  end

  def run_gem(*, chdir: @directory)
    run_command('-S', 'gem', *, chdir: chdir)
  end

  def run_command(*, chdir: @directory)
    output, status = Bundler.with_unbundled_env do
      Open3.capture2e(@environment, RbConfig.ruby, *, chdir: chdir)
    end
    assert_predicate status, :success?, output
    output
  end
end
