# frozen_string_literal: true

require 'optparse'
require_relative 'enforcement_config'
require_relative 'enforcement_coverage'
require_relative 'error'

module Shaka
  # Reports what enforces each rule the packaged workflow states with never, must, do not,
  # or only when. Whether an entry's answer is true is for a human to review; this renders it.
  class Enforcement
    QUESTION = 'Each row answers one question: if an agent ignores this rule, does anything fail?'
    LEGEND = "- `code` — a `shaka` command refuses the action after checking the state it governs.\n" \
             "- `reported` — a command surfaces the violation; the agent can still proceed.\n" \
             "- `github` — a repository setting refuses it.\n" \
             '- `agent` — nothing checks it; the note says what is missing.'
    SCOPE = 'This audit covers the rules workflow.yml states with never, must, do not, or ' \
            'only when. Its other imperative sentences, such as restrictive `only ...` ' \
            'clauses, are outside it. It reads packaged text alone: nothing here confirms ' \
            'that a GitHub setting is still active.'
    HEADER = "| Rule | Enforced by | What backs it |\n| --- | --- | --- |"

    def self.run(arguments)
      new(arguments).run
    rescue OptionParser::ParseError, Shaka::Error => e
      warn "shaka: #{e.message}"
      1
    end

    def initialize(arguments)
      @arguments = arguments.dup
    end

    def run
      parser = option_parser
      parser.parse!(@arguments)
      return help(parser) if @help

      raise OptionParser::InvalidArgument, parser.to_s unless @arguments.empty?

      workflow = WorkflowConfig.load
      puts render(EnforcementConfig.load(workflow:).fetch('rules'), workflow)
      0
    end

    private

    def option_parser
      OptionParser.new do |flags|
        flags.banner = 'Usage: shaka enforcement'
        flags.on('-h', '--help', 'Show usage') { @help = true }
      end
    end

    def help(parser)
      puts parser
      0
    end

    def render(rules, workflow)
      titles = section_titles(workflow)
      sections = titles.filter_map do |id, title|
        listed = rules.select { |rule| rule['phase'] == id }
        "## #{title}\n\n#{HEADER}\n#{listed.map { |rule| row(rule) }.join("\n")}" unless listed.empty?
      end
      ['# Workflow rule enforcement', "Audit source: `#{EnforcementConfig::PATH}`",
       tally(rules), QUESTION, LEGEND, SCOPE, *sections].join("\n\n")
    end

    def section_titles(workflow)
      titles = workflow.fetch('phases').to_h { |phase| [phase.fetch('id'), phase.fetch('title')] }
      titles.merge('always' => 'Always', 'code_quality' => 'Code quality')
    end

    def tally(rules)
      counts = rules.group_by { |rule| rule.fetch('enforced_by') }.transform_values(&:length)
      "#{rules.length} audited rules: #{counts.fetch('code', 0)} refused by a command, " \
        "#{counts.fetch('reported', 0)} reported by one, #{counts.fetch('github', 0)} refused by GitHub, " \
        "and #{counts.fetch('agent', 0)} enforced by nothing but the agent."
    end

    def row(rule)
      backing = rule['detector'] || rule.fetch('note')
      "| #{cell(rule.fetch('quote'))} | #{rule.fetch('enforced_by')} | #{cell(backing)} |"
    end

    # Folded YAML carries newlines, and a stray pipe would split the row it belongs in.
    def cell(text) = EnforcementCoverage.normalize(text).gsub('|', '\\|')
  end
end
