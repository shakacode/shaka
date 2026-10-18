# frozen_string_literal: true

require 'English'
require_relative 'official_take_over_support'

# A take-over that fails changes nothing, and concurrent installs cannot undo each other.
class OfficialTakeOverRollbackTest < Minitest::Test
  include OfficialTakeOverSupport

  def test_a_failure_after_switching_links_restores_them
    install_two_hosts
    record = File.join(@root, '.git/shaka-install.json')
    before = File.binread(record)
    # The links switch, then renaming the old record fails.
    File.chmod(0o555, File.join(@root, '.git'))
    assert_rolled_back(*invoke('--directory', @second, '--take-over'))
    assert_equal [before, false], [File.binread(record), File.exist?(File.join(@second, '.git/shaka-install.json'))]
  ensure
    File.chmod(0o755, File.join(@root, '.git'))
  end

  def test_a_failed_save_puts_back_the_old_record_and_links
    install_two_hosts
    record = File.join(@root, '.git/shaka-install.json')
    before = File.binread(record)
    assert_rolled_back(*Open3.capture2e({ 'HOME' => @home }, RbConfig.ruby, '-r', failing_save, @installer,
                                        '--directory', @second, '--take-over'))
    assert_equal before, File.binread(record)
    assert_empty Dir.glob(File.join(@root, '.git/shaka-install.retired-*.json'))
  end

  # Each runs from a checkout that owns some links, so each finds the other as the owner.
  def test_opposite_take_overs_finish
    install_opposite_owners
    pids = [@root, @second].map do |directory|
      Process.spawn({ 'HOME' => @home }, RbConfig.ruby, @installer, '--directory', directory, '--take-over',
                    %i[out err] => File::NULL)
    end
    assert_equal [true, true], finished(pids)
  end

  # A take-over waiting for one checkout lock must not hold the other, or two opposite ones deadlock.
  def test_a_waiting_take_over_holds_no_checkout_lock
    install_opposite_owners
    File.open(File.join(@second, '.git/.shaka-install.lock'), File::RDWR) do |lock|
      lock.flock(File::LOCK_EX)
      pid = Process.spawn({ 'HOME' => @home }, RbConfig.ruby, @installer, '--directory', @root, '--take-over',
                          %i[out err] => File::NULL)
      sleep 3
      assert File.open(File.join(@root, '.git/.shaka-install.lock'), File::RDWR) { |own| own.flock(File::LOCK_EX | File::LOCK_NB) }
      lock.flock(File::LOCK_UN)
      assert_equal [true], finished([pid])
    end
  end

  def test_take_over_switches_no_host_until_it_holds_every_host_lock
    install_two_hosts
    File.open(File.join(File.dirname(@claude), '.shaka-install.lock'), File::RDWR) do |lock|
      lock.flock(File::LOCK_EX)
      pid = spawn_take_over
      assert_links_point_at(@root)
      lock.flock(File::LOCK_UN)
      Process.wait(pid)
    end
    assert_predicate $CHILD_STATUS, :success?
    assert_links_point_at(@second)
  end

  private

  # The first checkout owns the Codex link and the second owns the Claude link.
  def install_opposite_owners
    git('clone', '-q', @remote, @second)
    [[@root, 'codex'], [@second, 'claude']].each do |directory, agent|
      output, status = invoke('--directory', directory, '--repository', @remote, '--agent', agent)
      assert_predicate status, :success?, output
    end
  end

  # Returns once the take-over has recorded its Ruby, just before it takes the host locks.
  def spawn_take_over
    pid = Process.spawn({ 'HOME' => @home }, RbConfig.ruby, @installer, '--directory', @second, '--take-over',
                        %i[out err] => File::NULL)
    wait_for { File.exist?(File.join(@second, '.git/shaka-ruby')) }
    sleep 1
    pid
  end

  # Exit success of each process, or a failed assertion after a minute so a deadlock cannot hang the suite.
  def finished(pids)
    statuses = {}
    wait_for { statuses.merge!(reaped(pids - statuses.keys)).size == pids.size }
    pids.map { |pid| statuses.fetch(pid).success? }
  ensure
    (pids - statuses.keys).each { |pid| stop(pid) }
  end

  def reaped(pids) = pids.filter_map { |pid| Process.wait2(pid, Process::WNOHANG) }.to_h

  def stop(pid)
    Process.kill('KILL', pid)
    Process.wait(pid)
  rescue Errno::ESRCH, Errno::ECHILD
    nil
  end

  def assert_rolled_back(output, status)
    refute_predicate status, :success?
    assert_includes output, 'links point at'
    assert_links_point_at(@root)
  end

  # Loads the copied Checkout, then makes saving the new record fail after the links switch.
  def failing_save
    path = File.join(@directory, 'failing_save.rb')
    File.write(path, <<~RUBY)
      require #{File.join(@source, 'lib/shaka/install/checkout.rb').inspect}
      Shaka::Install::Checkout.prepend(Module.new { def save(*) = raise(Errno::EIO, 'injected save failure') })
    RUBY
    path
  end
end
