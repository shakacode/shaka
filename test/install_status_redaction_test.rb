# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/install/status_states'

# Status keeps only a plain SSH login in an origin URL; any other user info could be a token.
class InstallStatusRedactionTest < Minitest::Test
  STATES = Shaka::Install::StatusStates

  def test_a_plain_ssh_login_is_kept
    %w[ssh://git@github.com/o/s.git git+ssh://git@example.com/s.git].each do |url|
      assert_equal url, STATES.redact(url)
      refute STATES.credentials?(url)
    end
  end

  def test_user_info_under_any_other_scheme_is_removed
    { 'ftps://token@host/s.git' => 'ftps://host/s.git',
      'persistent-https://token@host/s.git' => 'persistent-https://host/s.git',
      'https://user:p@ss@github.com/s.git' => 'https://github.com/s.git',
      'ssh://user:password@host/s.git' => 'ssh://host/s.git' }.each do |url, redacted|
      assert_equal redacted, STATES.redact(url)
      assert STATES.credentials?(url)
    end
  end
end
