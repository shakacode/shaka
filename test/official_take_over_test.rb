# frozen_string_literal: true

require_relative 'official_install_support'

# A second checkout takes every host link from the registered one in one step, or changes nothing.
class OfficialTakeOverTest < Minitest::Test
  include OfficialInstallSupport

  def setup
    super
    @second = File.join(@directory, 'second')
    @claude = File.join(@home, '.claude/skills/shaka')
  end

  def test_take_over_moves_every_host_and_retires_the_old_record
    install_two_hosts
    output, status = invoke('--directory', @second, '--take-over')
    assert_predicate status, :success?, output
    assert_links_point_at(@second)
    assert_retired_and_registered
    output, status = Open3.capture2e({ 'HOME' => @home }, RbConfig.ruby, File.join(@second, 'bin/install'), '--verify')
    assert_predicate status, :success?, output
  end

  def test_a_failure_after_switching_links_restores_them
    install_two_hosts
    record = File.join(@root, '.git/shaka-install.json')
    before = File.binread(record)
    # The links switch, then renaming the old record fails.
    File.chmod(0o555, File.join(@root, '.git'))
    output, = invoke('--directory', @second, '--take-over')
    assert_includes output, 'links point at'
    assert_links_point_at(@root)
    assert_equal [before, false], [File.binread(record), File.exist?(File.join(@second, '.git/shaka-install.json'))]
  ensure
    File.chmod(0o755, File.join(@root, '.git'))
  end

  def test_take_over_without_another_owner_refuses
    output, status = invoke('--directory', @second, '--take-over')
    refute_predicate status, :success?
    assert_includes output, 'No other registered checkout owns the Shaka links'
  end

  def test_take_over_rejects_maintenance_and_host_selection
    [%w[--take-over --update], %w[--take-over --agent codex]].each do |flags|
      output, status = invoke(*flags)
      refute_predicate status, :success?
      assert_includes output, 'Use --take-over alone'
    end
  end

  private

  def assert_retired_and_registered
    refute_path_exists File.join(@root, '.git/shaka-install.json')
    assert_equal 1, Dir.glob(File.join(@root, '.git/shaka-install.retired-*.json')).size
    record = JSON.parse(File.read(File.join(@second, '.git/shaka-install.json')))
    assert_equal [@remote, 2], [record['repository'], record['targets'].size]
  end

  def assert_links_point_at(checkout)
    [@destination, @claude].each do |link|
      assert_equal File.join(File.realpath(checkout), 'skills/shaka'), File.realpath(link)
    end
  end

  # The custom directory and the Claude host directory both point at the first checkout.
  def install_two_hosts
    official_install
    output, status = invoke('--directory', @root, '--repository', @remote, '--agent', 'claude')
    assert_predicate status, :success?, output
  end
end
