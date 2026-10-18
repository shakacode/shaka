# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/update_check'

# Runs update-check against canned git and GitHub answers and records each command.
module UpdateCheckSupport
  SHA = 'a' * 40
  PULLED = 'b' * 40
  CHECKOUT = '/installed path'
  SOURCE = { 'kind' => 'revision', 'revision' => SHA,
             'repository' => 'https://github.com/shakacode/shaka.git' }.freeze
  DEFAULTS = { source: SOURCE, branch: 'main', checkout: CHECKOUT, ahead_by: 3, head: SHA, github: nil }.freeze

  def check(status, **options)
    options = DEFAULTS.merge(options)
    @calls = []
    github = options[:github] || [JSON.generate({ 'status' => status, 'ahead_by' => options[:ahead_by] }), '', true]
    runner = lambda do |argv, directory|
      @calls << [argv, directory]
      argv.first == 'git' ? ["#{options[:head]}\n", '', true] : github
    end
    Shaka::UpdateCheck.new(source: options[:source], branch: options[:branch], checkout: options[:checkout],
                           helper: '/installed path/scripts/shaka', runner:).result
  end
end
