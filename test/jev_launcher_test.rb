# frozen_string_literal: true

require_relative 'test_helper'

class JevLauncherTest < Minitest::Test
  def test_safe_ruby_symlink_keeps_its_command_name
    with_dispatcher do |dir|
      launcher = File.expand_path('../skills/shaka-jev/scripts/analyze', __dir__)
      output, status = Open3.capture2e({ 'PATH' => "#{dir}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH')}" },
                                       launcher, '--help')

      assert_predicate status, :success?
      assert_equal "#{File.realpath(dir)}/ruby\n", output
    end
  end

  private

  def with_dispatcher
    Dir.mktmpdir('jev-ruby-dispatch') do |dir|
      dispatcher = File.join(dir, 'dispatcher')
      File.write(dispatcher, "#!/bin/sh\nprintf '%s\\n' \"$0\"\n")
      File.chmod(0o755, dispatcher)
      File.symlink(dispatcher, File.join(dir, 'ruby'))
      yield dir
    end
  end
end
