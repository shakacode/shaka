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
  # No saved answers live in a home that does not exist, so each check asks GitHub unless a test saves one.
  DEFAULTS = { source: SOURCE, branch: 'main', checkout: CHECKOUT, ahead_by: 3, head: SHA, github: nil,
               published: ['', '', true], pulled: ['', '', true], registered: nil, home: '/no saved answers' }.freeze

  def check(status, **) = checker(status, **).result

  def checker(status, **options)
    @options = DEFAULTS.merge(options)
    @calls = []
    @github = @options[:github] || [JSON.generate({ 'status' => status, 'ahead_by' => @options[:ahead_by],
                                                    'oldest' => '2020-01-01T00:00:00Z' }), '', true]
    offline.new(source: @options[:source], branch: @options[:branch], checkout: @options[:checkout],
                helper: '/installed path/scripts/shaka', runner: method(:answer))
  end

  # The real lookups read this machine's home, so tests name the registered helper and home themselves.
  def offline
    registered, home = @options.values_at(:registered, :home)
    Class.new(Shaka::UpdateCheck) do
      define_method(:registered_helper) { registered }
      define_method(:home) { home }
    end
  end

  def answer(argv, directory)
    @calls << [argv, directory]
    return @github unless argv.first == 'git'
    return ["#{@options[:head]}\n", '', true] unless argv.include?('merge-base')

    argv.last.start_with?('refs/') ? @options[:published] : @options[:pulled]
  end
end
