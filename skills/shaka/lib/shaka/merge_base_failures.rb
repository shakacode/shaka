# frozen_string_literal: true

require_relative 'base_checks'
require_relative 'error'

module Shaka
  # The checks named with `merge --auto --base-failure`. Auto excuses one only when it is not
  # required, fails on the head, and fails on the newest commit of the base branch too. Ruby
  # checks those facts; the agent has compared the two logs and found that the diff leaves the
  # check's inputs alone.
  class MergeBaseFailures
    attr_reader :evidence

    def initialize(github, names)
      @github = github
      @names = Array(names).uniq
      @evidence = {}
    end

    def any? = !@names.empty?

    # Returns the head rows it excuses. required_names is nil when required checks are unknown.
    def excuse(not_passing, required_names, base)
      return [] unless any?
      raise Error, 'Required checks are unknown, so no check can be excused as a base failure.' if required_names.nil?

      @names.each { |name| verify_head(name, not_passing, required_names) }
      sha = verify_base(base)
      @evidence = { 'base_failures_excused' => { 'base' => base, 'base_sha' => sha, 'checks' => @names } }
      not_passing.select { |check| @names.include?(check['name']) }
    end

    private

    def verify_head(name, not_passing, required_names)
      raise Error, "#{name} is a required check, so Auto cannot merge past it." if required_names.include?(name)

      rows = not_passing.select { |check| check['name'] == name }
      return if !rows.empty? && rows.all? { |check| check['bucket'] == 'fail' }

      raise Error, "--base-failure #{name} names no failing check on the head; drop the flag or wait for the check."
    end

    def verify_base(base)
      sha, on_base = BaseChecks.read(@github, base)
      @names.each do |name|
        bucket = BaseChecks.bucket(on_base[name])
        next if bucket == 'fail'

        raise Error, "#{name} does not fail on #{base} at #{sha} (#{bucket}). Repair it in this PR, " \
                     "or update the branch if #{base} now passes."
      end
      sha
    end
  end
end
