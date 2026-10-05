# frozen_string_literal: true

require_relative 'handoff_helper'

class HandoffOwnerTest < Minitest::Test
  include HandoffHarness

  def test_live_owner_missing_the_machine_is_owed_even_with_a_current_revision
    edited = description.sub('| Owner | m5 · Claude Code · k7q2 |', '| Owner | Codex · 01a109ad |')
    result = handoff(body: edited)

    assert(result.fetch('owed').any? { |item| item.include?('machine alias · host · owner tag') })
    assert_equal 2, Shaka::Handoff.exit_status(result)
  end

  def test_unknown_owner_remains_recoverable
    edited = description.sub('| Owner | m5 · Claude Code · k7q2 |', '| Owner | UNKNOWN |')

    assert_empty handoff(body: edited).fetch('owed')
  end
end
