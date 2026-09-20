# frozen_string_literal: true

require_relative 'test_helper'
require 'fileutils'
require 'json'
require 'yaml'

module ReposCatalogHelpers
  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)

  def with_home
    Dir.mktmpdir('shaka-repos-home') do |home|
      Dir.mktmpdir('shaka-repos-roots') do |roots|
        @roots = roots
        yield home
      end
    end
  end

  def env(home)
    { 'SHAKA_HOME' => home, 'PATH' => ENV.fetch('PATH') }
  end

  def refresh(home)
    catalog, error, status = refresh_result(home)
    raise error unless status.success?

    catalog
  end

  def refresh_result(home)
    output, error, status = Open3.capture3(env(home), COMMAND, 'repos', 'refresh')
    path = File.join(home, 'catalog.json')
    catalog = File.file?(path) ? JSON.parse(File.read(path)) : {}
    [output.empty? ? catalog : JSON.parse(output), error, status]
  end

  def registered_repository(home, name:, prefix: nil)
    root = repository(name:, prefix:)
    _output, error, status = Open3.capture3(env(home), COMMAND, 'repos', 'add', '--root', root)
    raise error unless status.success?

    root
  end

  def repository(name:, prefix: nil)
    root = File.join(@roots, name)
    write_seam(root, prefix)
    git_origin!(root, name)
    File.realpath(root)
  end

  def identities(catalog)
    catalog.fetch('repositories').map { |row| row.fetch('identity') }
  end

  def expected_row(name, root, prefix:, source:)
    { 'identity' => "acme/#{name}", 'url' => "https://github.com/acme/#{name}",
      'root' => root, 'prefix' => prefix, 'prefix_source' => source }
  end

  private

  def write_seam(root, prefix)
    FileUtils.mkdir_p(File.join(root, '.agents/bin'))
    %w[setup validate test].each do |bin|
      path = File.join(root, '.agents/bin', bin)
      File.write(path, "#!/bin/sh\nexit 0\n")
      File.chmod(0o755, path)
    end
    extra = prefix ? { 'repo_prefix' => prefix } : {}
    File.write(File.join(root, '.agents/agent-workflow.yml'), YAML.dump(seam_config.merge(extra)))
  end

  def git_origin!(root, name)
    git!(root, 'init', '-b', 'main')
    git!(root, 'add', '.')
    git!(root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-m', 'trusted')
    git!(root, 'remote', 'add', 'origin', "https://github.com/acme/#{name}.git")
    git!(root, 'update-ref', 'refs/remotes/origin/main', 'HEAD')
    git!(root, 'symbolic-ref', 'refs/remotes/origin/HEAD', 'refs/remotes/origin/main')
  end

  def seam_config
    {
      'version' => 1, 'base_branch' => 'main',
      'review' => { 'required' => 'none' },
      'merge' => { 'preference' => 'ask' }
    }
  end

  def git!(root, *)
    output, status = Open3.capture2e('git', '-C', root, *)
    raise output unless status.success?
  end
end

class ReposCatalogTest < Minitest::Test
  include ReposCatalogHelpers

  def test_refresh_rebuilds_the_catalog_from_trusted_seams
    with_home do |home|
      first = registered_repository(home, name: 'alpha', prefix: 'ALP')
      second = registered_repository(home, name: 'beta')
      catalog = refresh(home)
      rows = [expected_row('alpha', first, prefix: 'ALP', source: 'seam'),
              expected_row('beta', second, prefix: 'BETA', source: 'fallback')]

      assert_equal rows, catalog.fetch('repositories')
      assert_empty catalog.fetch('duplicate_prefixes')
    end
  end

  def test_refresh_reconstructs_a_deleted_catalog
    with_home do |home|
      registered_repository(home, name: 'alpha', prefix: 'ALP')
      refresh(home)
      FileUtils.rm(File.join(home, 'catalog.json'))

      assert_equal ['acme/alpha'], identities(refresh(home))
    end
  end

  def test_direct_prefix_lookup_does_not_need_the_catalog
    with_home do |home|
      root = repository(name: 'solo', prefix: 'SOLO')
      output, error, status = Open3.capture3(env(home), COMMAND, 'prefix', '--root', root)

      assert status.success?, error
      assert_equal({ 'prefix' => 'SOLO', 'source' => 'seam' }, JSON.parse(output))
      refute File.exist?(File.join(home, 'catalog.json'))
    end
  end

  def test_refresh_ignores_a_candidate_seam_and_reads_the_trusted_ref
    with_home do |home|
      root = registered_repository(home, name: 'alpha', prefix: 'TRUST')
      path = File.join(root, '.agents/agent-workflow.yml')
      File.write(path, File.read(path).sub('TRUST', 'DIRTY'))
      catalog = refresh(home)

      assert_equal 'TRUST', catalog.dig('repositories', 0, 'prefix')
      assert_equal 'seam', catalog.dig('repositories', 0, 'prefix_source')
    end
  end

  def test_refresh_reports_duplicate_prefixes_without_changing_identity
    with_home do |home|
      registered_repository(home, name: 'alpha', prefix: 'DUP')
      registered_repository(home, name: 'beta', prefix: 'DUP')
      catalog, error, status = refresh_result(home)

      refute status.success?
      assert_includes error, 'DUP'
      assert_equal %w[acme/alpha acme/beta], catalog.dig('duplicate_prefixes', 'DUP')
      assert_equal %w[acme/alpha acme/beta], identities(catalog)
    end
  end
end
