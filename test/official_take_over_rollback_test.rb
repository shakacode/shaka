# frozen_string_literal: true

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

  # Ctrl-C raises Interrupt, which is not a StandardError; both must roll back.
  def test_a_failed_or_interrupted_save_puts_back_the_old_record_and_links
    record = File.join(@root, '.git/shaka-install.json')
    install_two_hosts
    before = File.binread(record)
    %w[Errno::EIO Interrupt].each do |error|
      assert_rolled_back(*take_over_with(checkout_patch("def save(*) = raise(#{error})")))
      assert_equal before, File.binread(record)
      assert_empty Dir.glob(File.join(@root, '.git/shaka-install.retired-*.json'))
    end
  end

  def test_an_interrupt_while_switching_a_host_puts_every_link_back
    install_two_hosts
    before = File.binread(File.join(@root, '.git/shaka-install.json'))
    patch = links_patch('def switch_and_record(*) = super.tap { raise Interrupt if @skills_dir.include?(".claude") }')
    assert_rolled_back(*take_over_with(patch))
    assert_equal before, File.binread(File.join(@root, '.git/shaka-install.json'))
  end

  # Once the new record is saved the take-over stands, so a late interrupt must not move links back.
  def test_an_interrupt_after_the_new_record_is_saved_keeps_the_take_over
    install_two_hosts
    output, status = take_over_with(checkout_patch('def save(*) = super.tap { raise Interrupt }'))
    refute_predicate status, :success?
    refute_includes output, 'links point at'
    assert_links_point_at(@second)
    assert_path_exists File.join(@second, '.git/shaka-install.json')
    refute_path_exists File.join(@root, '.git/shaka-install.json')
  end

  private

  def assert_rolled_back(output, status)
    refute_predicate status, :success?
    assert_includes output, 'links point at'
    assert_links_point_at(@root)
  end
end
