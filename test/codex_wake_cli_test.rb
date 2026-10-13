# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/hosts/codex_wake'

class CodexWakeCliTest < Minitest::Test
  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  THREAD = '11111111-2222-4333-8444-555555555555'

  def test_codex_shell_watcher_cannot_supply_an_automatic_handoff
    Dir.mktmpdir do |directory|
      environment = fake_git_environment(directory)
      _output, error, status = Open3.capture3(environment, COMMAND, 'handoff', 'owner/repo', '42',
                                              '--ref', 'a' * 40, '--head', 'b' * 40,
                                              '--woken-by', 'SHAKA_WAKE shell watcher')

      refute_predicate status, :success?
      assert_includes error, 'Codex automatic handoff requires --codex-wake'
      refute_includes error, 'unexpected-github-read'
    end
  end

  private

  def fake_git_environment(directory)
    gh = File.join(directory, 'gh')
    File.write(gh, "#!/bin/sh\necho unexpected-github-read >&2\nexit 99\n")
    File.chmod(0o755, gh)
    foreign = Shaka::CodexWake::OTHER_HOSTS.to_h { |key| [key, nil] }.merge('PI_CODING_AGENT' => nil)
    foreign.merge('CODEX_THREAD_ID' => THREAD, 'PATH' => "#{directory}:#{ENV.fetch('PATH')}")
  end
end
