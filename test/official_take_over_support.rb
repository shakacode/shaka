# frozen_string_literal: true

require_relative 'official_install_support'

# A first checkout that owns two hosts' links, and a second directory that takes them over.
module OfficialTakeOverSupport
  include OfficialInstallSupport

  def setup
    super
    @second = File.join(@directory, 'second')
    @claude = File.join(@home, '.claude/skills/shaka')
  end

  private

  def wait_for
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 60
    sleep 0.1 until yield || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
    assert yield, 'timed out waiting for the take-over'
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
