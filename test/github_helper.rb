# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/github'

module GitHubHelper
  HEAD = 'a' * 40
  BASE = 'b' * 40
  STATUS = Struct.new(:exitstatus)

  def client(*responses)
    @calls = []
    runner = lambda do |argv, stdin_data:|
      @calls << [argv, stdin_data]
      responses.shift || raise('Unexpected GitHub request')
    end
    Shaka::GitHub.new('owner/repo', 42, runner: runner)
  end

  def response(value, status: 0, http_status: nil)
    stderr = http_status ? "gh: request failed (HTTP #{http_status})" : 'private stderr must not be disclosed'
    [JSON.generate(value), stderr, STATUS.new(status)]
  end

  def snapshot_response(head: HEAD, state: 'OPEN')
    response({ 'data' => { 'repository' => { 'pullRequest' => { 'headRefOid' => head, 'state' => state } } } })
  end

  def review_response(**changes)
    response({ 'id' => 123, 'state' => 'COMMENTED', 'commit_id' => HEAD, 'body' => 'A walkthrough.' }.merge(changes))
  end
end
