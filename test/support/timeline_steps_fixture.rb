# frozen_string_literal: true

require 'json'
require 'tmpdir'
require 'shaka/publication/timeline_steps'

# Call-log records, bodies, and pull requests for the measured-steps tests.
module TimelineStepsFixture
  REPOSITORY = 'acme/widgets'
  HEAD = 'a' * 40
  TREE = 'b' * 40
  COMMITS = [{ 'oid' => HEAD, 'tree' => TREE }].freeze
  GitHub = Struct.new(:repository)

  def record(**fields)
    { 'at' => '2026-10-21T09:00:00Z', 'exit' => 0, 'duration_ms' => 60_000 }.merge(fields.transform_keys(&:to_s))
  end

  def validation(**) = record(command: 'evidence run', check: 'validate', repository: REPOSITORY, tree: TREE, **)
  def review(**) = record(command: 'review run', head: HEAD, provider: 'openai', **)

  def logged(*records, commits: COMMITS, machine: 'm5')
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'calls.jsonl')
      File.write(path, records.map { |entry| entry.is_a?(String) ? "#{entry}\n" : "#{JSON.generate(entry)}\n" }.join)
      Shaka::TimelineSteps.logged(path, REPOSITORY, commits, machine)
    end
  end

  def body(steps, dropped: 0) = region(Shaka::TimelineSteps.hidden(steps, dropped))

  def commands(steps) = steps.map { |step| step['command'] }

  def pull(body, head: REPOSITORY)
    { 'body' => body, 'head' => { 'repo' => { 'full_name' => head } },
      'base' => { 'repo' => { 'full_name' => REPOSITORY } } }
  end

  def attached(log, pull) = attach(log, pull)['steps']

  def reviews_at_each_minute = (0..59).map { |minute| review(at: format('2026-10-21T10:%02d:00Z', minute)) }

  def region(line) = "<!-- shaka:begin -->\n#{line}\n<!-- shaka:end -->"

  def with_log(*records)
    Dir.mktmpdir do |directory|
      log = File.join(directory, 'calls.jsonl')
      File.write(log, records.map { |entry| "#{JSON.generate(entry)}\n" }.join)
      yield log
    end
  end

  def attach(log, pull)
    env = { 'SHAKA_CALL_LOG' => log, 'SHAKA_MACHINE_ALIAS' => nil }
    Shaka::TimelineSteps.attach({ 'commits' => COMMITS }, GitHub.new(REPOSITORY), pull, env:)
  end
end
