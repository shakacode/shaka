# frozen_string_literal: true

require_relative 'test_helper'

class JevLauncherTest < Minitest::Test
  def test_safe_ruby_symlink_keeps_its_command_name
    with_dispatcher do |dir|
      output, status = run_launcher(dir)

      assert_predicate status, :success?
      assert_equal "#{File.realpath(dir)}/ruby\n", output
    end
  end

  def test_external_path_with_candidate_backed_helper_is_rejected
    with_candidate_helper do |dir|
      output, status = run_launcher(dir)

      assert_predicate status, :success?
      assert_match(/Usage: analyze/, output)
      refute_match(/FAKE RUBY/, output)
    end
  end

  private

  def run_launcher(dir)
    launcher = File.expand_path('../skills/shaka-jev/scripts/analyze', __dir__)
    Open3.capture2e({ 'PATH' => "#{dir}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH')}" }, launcher, '--help')
  end

  def with_candidate_helper
    Dir.mktmpdir('jev-candidate-', Dir.pwd) do |candidate|
      Dir.mktmpdir('jev-external-') do |external|
        helper = File.join(candidate, 'helper')
        File.write(helper, "#!/bin/sh\nexit 99\n")
        File.symlink(helper, File.join(external, 'helper'))
        write_fake_ruby(external)
        yield external
      end
    end
  end

  def write_fake_ruby(dir)
    ruby = File.join(dir, 'ruby')
    File.write(ruby, "#!/bin/sh\nprintf 'FAKE RUBY\\n'\n")
    File.chmod(0o755, ruby)
  end

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
