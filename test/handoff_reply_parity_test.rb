# frozen_string_literal: true

require_relative 'handoff_helper'
require 'shaka/public_comments/reply_guard'

# #1323: handoff stops owing a thread only when `reply` would refuse it, so both screens must
# reach the same answer for the same authors.
class HandoffReplyParityTest < Minitest::Test
  include HandoffHarness

  TRUST = { users: ['reviewer'], bots: ['coderabbitai'], metadata_bots: [], teams: [] }.freeze
  ACCOUNT = 'shaka-agent'

  CASES = {
    'excluded opener' => [%w[outsider], {}],
    'writer' => [%w[maintainer], { writers: ['maintainer'] }],
    'configured user' => [%w[reviewer], {}],
    'configured bot' => [%w[coderabbitai[bot]], {}],
    'unconfigured bot' => [%w[dependabot[bot]], {}],
    'unverifiable author' => [%w[outsider], { unverifiable: ['outsider'] }],
    'excluded reply' => [%w[reviewer outsider], {}],
    'agent reply then excluded author' => [%w[reviewer shaka-agent outsider], {}]
  }.freeze

  CASES.each do |name, (logins, pull)|
    define_method("test_#{name.tr(' ', '_')}") do
      github = HandoffFakeGitHub.new(pull.merge(visibility: 'public'))
      refused = refused?(github, logins)
      result = Shaka::Handoff::ThreadScreen.new(github, trust_config: TRUST).call({ 'T1' => posts(logins) }, ACCOUNT)

      assert_equal refused, (result.excluded + result.unverified).include?('T1'), name
    end
  end

  private

  def posts(logins) = logins.map { |login| [login, 'Body.'] }

  def refused?(github, logins)
    guard = Shaka::PublicComments::ReplyGuard.new(github, trust_config: TRUST, machine_path: '/nonexistent')
    guard.check(rest_comments(logins), 1, ACCOUNT)
    false
  rescue Shaka::Error => e
    raise unless e.message.include?('excluded author')

    true
  end

  # The same thread as REST lists it: the root, then replies to it.
  def rest_comments(logins)
    logins.each_with_index.map do |login, index|
      { 'id' => index + 1, 'in_reply_to_id' => index.zero? ? nil : 1,
        'user' => { 'login' => login, 'type' => login.end_with?('[bot]') ? 'Bot' : 'User' } }
    end
  end
end
