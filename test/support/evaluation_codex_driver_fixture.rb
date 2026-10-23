# frozen_string_literal: true

require_relative 'evaluation_delivery_fixture'

module EvaluationCodexDriverFixture
  include EvaluationDeliveryFixture

  def setup
    super
    source = File.read(File.expand_path('../fixtures/evaluation_delivery/driver_gh.txt', __dir__))
    File.write(@gh, "#!#{RbConfig.ruby}\n#{source}")
    File.write(File.join(@directory, 'mode'), '')
    @output = File.join(@directory, 'driver')
  end

  private

  def run_driver(sequence: [HEAD], verifier: 'exit 0', max_attempts: 4, seconds: 10, writer: nil)
    plan = { 'repository' => 'fixture-org/cell', 'number' => 1,
             'driver_actor' => 'fixture-agent', 'clock_id' => 'driver-clock' }
    @writer = writer || Shaka::Evaluation::CodexDriver.new(plan, github: @gh, environment: {},
                                                                 verifier: { command: [RbConfig.ruby, '-e', verifier],
                                                                             cwd: @directory, environment: {} },
                                                                 max_attempts:)
    command = [RbConfig.ruby, child, JSON.generate(sequence), @mode || (@buffered ? 'buffered' : 'stream')]
    @writer.run(command:, cwd: @directory,
                directory: @output, seconds:)
  end

  def child = File.expand_path('../fixtures/evaluation_delivery/codex_driver.txt', __dir__)

  def ledger = File.readlines(File.join(@output, 'ledger.jsonl')).map { JSON.parse(it) }

  def posts
    path = File.join(@directory, 'calls.jsonl')
    File.exist?(path) ? File.readlines(path).map { JSON.parse(it) }.select { it.fetch('argv').include?('POST') } : []
  end
end
