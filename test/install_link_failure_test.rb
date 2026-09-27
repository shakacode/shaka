# frozen_string_literal: true

require_relative 'install_support'
require 'shaka/install/links'

class InstallLinkFailureTest < Minitest::Test
  include InstallTestSupport

  def test_failed_second_link_restores_the_first
    output, status = install
    assert_predicate status, :success?, output
    original = File.readlink(@destination)

    capture_io { assert_raises(Errno::EACCES) { failing_linker.switch_all(replacement_package) } }
    assert_equal original, File.readlink(@destination)
  end

  private

  def failing_linker
    verifier = Object.new
    def verifier.verify(*) = nil
    failing_linker_class.new(@skills_dir, File.dirname(package_path), File.realpath(File.join(@directory, 'source')),
                             %w[shaka rct], verifier)
  end

  def failing_linker_class
    Class.new(Shaka::Install::Links) do
      private

      def switch_one(name, target)
        raise Errno::EACCES if name == 'rct'

        super
      end
    end
  end

  def replacement_package
    target = File.join(@directory, 'replacement')
    %w[shaka rct].each { |name| FileUtils.mkdir_p(File.join(target, 'skills', name)) }
    target
  end
end
