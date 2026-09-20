# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'shaka/doctor/cursor_stop_hook'

# Doctor must fail a missing stop command, not a missing this-chat usage file.
class CursorStopHookTest < Minitest::Test
  HOOK = { 'command' => 'skills/shaka/scripts/cursor-usage-hook' }.freeze

  # Break: treating an afterAgentResponse-only command as installed would pass doctor
  # while persist() still drops those payloads.
  def test_a_stop_array_command_is_installed
    with_hooks('afterAgentResponse' => [HOOK]) { |path| refute installed?(path) }
    with_hooks('stop' => [HOOK]) { |path| assert installed?(path) }
  end

  def test_a_missing_or_invalid_file_is_not_installed
    refute installed?('/definitely/missing/hooks.json')
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'hooks.json')
      File.write(path, '{')
      refute installed?(path)
    end
  end

  private

  def installed?(path)
    Shaka::Doctor::CursorStopHook.installed?(path)
  end

  def with_hooks(events)
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'hooks.json')
      File.write(path, JSON.generate('version' => 1, 'hooks' => events))
      yield path
    end
  end
end
