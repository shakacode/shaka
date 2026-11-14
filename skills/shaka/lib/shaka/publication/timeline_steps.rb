# frozen_string_literal: true

require 'digest'
require 'json'
require 'time'
require_relative '../call_log'
require_relative '../doctor/machine_alias'
require_relative 'managed_region'
require_relative 'provenance'

module Shaka
  # Collects a pull request's measured steps: the validation, local review, and product
  # checkpoint runs this machine's call log tagged with one of its commits, plus the steps an
  # earlier update carried in the body from any session or machine. A step whose record is
  # unreadable is left out, so neither source can block publication.
  module TimelineSteps
    NAMES = { 'evidence run' => 'Validation', 'review run' => 'Local review',
              'post-implementation run' => 'Product checkpoint' }.freeze
    # Validation runs that time the candidate; setup and the hosted CI trigger do not.
    CHECKS = %w[validate validate_local test].freeze
    HIDDEN = /^<!-- timeline-steps (\{.*\}) -->$/
    # The newest steps are kept, so the carried line stays a small part of GitHub's body limit.
    MAX_STEPS = 50
    ID = /\A[0-9a-f]{16}\z/

    module_function

    # Adds the steps to the timeline the timings section renders, with how many older ones are no
    # longer kept. A fork's author can edit its body, so steps carried there are not republished;
    # this machine's own log still counts.
    def attach(timeline, github, pull, env: ENV)
      fresh = logged(CallLog.path(env), github.repository, Array(timeline['commits']),
                     Doctor::MachineAlias.publishable(env))
      carried, dropped = same_repository?(pull) ? read(pull['body']) : [[], 0]
      kept, dropped = retain(merge(carried, unseen(fresh, carried, dropped)), dropped)
      timeline.merge('steps' => kept, 'dropped_steps' => dropped)
    end

    def retain(steps, dropped)
      kept = steps.last(MAX_STEPS)
      [kept, dropped + steps.size - kept.size]
    end

    # A logged step no newer than the oldest kept one, and not kept itself, was already counted as
    # dropped, so it is not counted again. Times have whole seconds, so steps can share the boundary.
    def unseen(fresh, carried, dropped)
      return fresh unless dropped.positive? && carried.any?

      oldest = carried.first['at']
      kept = carried.to_set { |step| step['id'] }
      fresh.reject { |step| step['at'] <= oldest && !kept.include?(step['id']) }
    end

    def same_repository?(pull)
      head, base = %w[head base].map { |side| pull.dig(side, 'repo', 'full_name') }
      head.is_a?(String) && head == base
    end

    # Steps are sorted by start time, and a step both carried and logged again appears once.
    # The id breaks ties, so the same steps are cut at the limit on every update.
    def merge(*lists) = lists.flatten.uniq { |step| step['id'] }.sort_by { |step| step.values_at('at', 'id') }

    # The dropped count travels with the steps, so a later reader knows the history is partial.
    def hidden(steps, dropped = 0) = "<!-- timeline-steps #{JSON.generate('steps' => steps, 'dropped' => dropped)} -->"

    def carried(body) = read(body).first

    # Only the helper's own region is read, so a step quoted elsewhere in the body is not carried.
    def read(body)
      line = Publishing.managed_region(body).to_s[HIDDEN, 1]
      data = line ? JSON.parse(line) : {}
      return [[], 0] unless data.is_a?(Hash)

      dropped = data['dropped']
      dropped = 0 unless dropped.is_a?(Integer) && dropped.positive?
      [Array(data['steps']).filter_map { |step| checked(step) }, dropped]
    rescue JSON::ParserError
      [[], 0]
    end

    def logged(path, repository, commits, machine)
      return [] if path.nil? || commits.empty?

      records = run_lines(path).filter_map { |line| parse(line) }
      records.select(&owned_by(repository, commits)).filter_map { |record| step(record, machine) }
    rescue SystemCallError, IOError
      []
    end

    # Every step command ends in `run`, so the log's other lines, the great majority, are not parsed.
    def run_lines(path) = File.foreach(path, encoding: 'UTF-8').select { |line| line.include?(' run"') }

    def owned_by(repository, commits)
      heads = commits.map { |commit| commit['oid'] }
      trees = commits.map { |commit| commit['tree'] }
      ->(record) { ours?(record, repository, heads, trees) }
    end

    def parse(line)
      record = JSON.parse(line)
      record if record.is_a?(Hash)
    rescue JSON::ParserError, EncodingError
      nil
    end

    # A review or checkpoint names the head it judged; a validation run names the tree it tested,
    # which is a commit's tree once that work is committed.
    def ours?(record, repository, heads, trees)
      return false unless [nil, repository].include?(record['repository'])

      if record['command'] == 'evidence run'
        CHECKS.include?(record['check']) && trees.include?(record['tree'])
      else
        NAMES.key?(record['command']) && heads.include?(record['head'])
      end
    end

    def step(record, machine)
      identity = record.values_at('at', 'command', 'check', 'head', 'tree', 'provider', 'duration_ms')
      checked(record.slice('command', 'check', 'at', 'duration_ms', 'exit', 'provider', 'model', 'effort')
                    .merge('id' => Digest::SHA256.hexdigest(JSON.generate(identity))[0, 16], 'machine' => machine))
    end

    # Carried steps come from an editable body, so every field is checked again before it renders.
    def checked(step)
      return unless step.is_a?(Hash) && valid_identity?(step) && valid_timing?(step)

      at = Time.iso8601(step['at']).utc.iso8601
      tags = %w[provider model effort].to_h { |key| [key, CallLog.shaped(key, step[key])] }
      step.slice('id', 'command', 'check', 'duration_ms', 'exit')
          .merge('at' => at, **tags, 'machine' => machine(step['machine'])).compact
    end

    def machine(value) = (value if value.is_a?(String) && ExecutionProvenance::SAFE_VALUE.match?(value))

    def valid_identity?(step)
      ID.match?(step['id'].to_s) && NAMES.key?(step['command']) &&
        (step['command'] == 'evidence run' ? CHECKS.include?(step['check']) : step['check'].nil?)
    end

    def valid_timing?(step)
      Time.iso8601(step['at'].to_s) && step['duration_ms'].is_a?(Integer) && !step['duration_ms'].negative? &&
        step['exit'].is_a?(Integer)
    rescue ArgumentError
      false
    end
  end
end
