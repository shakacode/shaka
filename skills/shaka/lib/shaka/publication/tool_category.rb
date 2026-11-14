# frozen_string_literal: true

require_relative 'shell_lines'

module Shaka
  # Names the fixed category a tool call's time counts under in a pull request's agent time. A shell
  # call is classed by the programs its command lines run, never by text in their arguments, so
  # reading a test file or a commit message that names a linter is not counted as validation.
  module ToolCategory
    SHELL_TOOLS = %w[Bash exec exec_command shell local_shell].freeze
    NAMED = { 'files' => %w[Read Edit Write MultiEdit Grep Glob NotebookEdit apply_patch view_image],
              'waiting' => %w[AskUserQuestion request_user_input],
              'subagents' => %w[Agent Task spawn_agent] }.freeze
    # When a call runs several command lines, the first category in this order names it.
    PRIORITY = %w[validation review helper git_github].freeze
    VALIDATION = %w[rubocop rspec pytest jest vitest eslint stylelint phpunit run-tests validate validate-local].freeze
    # Tools whose `test` subcommand runs the tests: `go test`, `cargo test`, `npm test`.
    TEST_RUNNERS = %w[npm yarn pnpm bun rake go cargo make mix dotnet].freeze
    # Words that run the command after them: `bundle exec rubocop` runs rubocop.
    WRAPPERS = %w[env time nice command exec nohup].freeze
    # `timeout` runs the command after its duration, whatever options come first.
    TIMEOUT_VALUED = %w[-k -s --kill-after --signal].freeze
    SHELLS = %w[bash sh zsh].freeze
    ASSIGNMENT = /\A\w+=/
    # A program named by a variable, such as `$H`, which holds the helper's path; `$(...)` is not one.
    VARIABLE = /\A\$\{?[A-Za-z_]\w*\}?\z/

    module_function

    def call(name, command)
      return 'browser_mcp' if name.start_with?('mcp__')

      NAMED.find { |_category, names| names.include?(name) }&.first || shell_category(name, command)
    end

    # A command given as a word list, as Codex records one, is a single argument vector already.
    def shell_category(name, command)
      return 'other_tools' unless SHELL_TOOLS.include?(name)

      found = argvs(name, command).flat_map { |argv| categories(argv) }
      PRIORITY.find { |category| found.include?(category) } || 'shell'
    end

    def argvs(name, command)
      return [command.map(&:to_s)] if command.is_a?(Array)

      ShellLines.lines(name, command.to_s).map { |line| ShellLines.words(line) }
    end

    # The categories one command line runs; `bash -c "..."` runs each line of its script.
    def categories(argv, depth = 0)
      argv = unwrap(argv)
      return [line_category(argv)].compact unless shell_script?(argv) && depth < 3

      ShellLines.lines('Bash', script(argv)).flat_map { |line| categories(ShellLines.words(line), depth + 1) }
    end

    # The category of one command line from the program it runs, or nil for any other program.
    def line_category(words)
      program = File.basename(words.first.to_s)
      return 'git_github' if %w[git gh].include?(program)
      return helper_category(words.drop(1)) if program == 'shaka' || words.first.to_s.match?(VARIABLE)

      'validation' if validation?(program, words.drop(1))
    end

    # Drops variable assignments and wrappers with their options to reach the program that runs.
    def unwrap(words)
      words = words.drop_while { |word| word.match?(ASSIGNMENT) }
      inner = wrapped(words.first.to_s, words)
      inner ? unwrap(inner) : words
    end

    # The words after a wrapper and its options, or nil when the first word is no wrapper.
    def wrapped(first, words)
      return words.drop(2) if first == 'bundle' && words[1] == 'exec'
      return after_duration(words.drop(1)) if first == 'timeout'

      words.drop(1).drop_while { |word| word.start_with?('-') || word.match?(/\A\d+\z/) } if WRAPPERS.include?(first)
    end

    # Skips timeout's options, with the values `-k`, `-s`, `--kill-after`, and `--signal` take, then
    # its duration.
    def after_duration(words)
      return words.drop(1) unless words.first.to_s.start_with?('-')

      after_duration(words.drop(TIMEOUT_VALUED.include?(words.first) ? 2 : 1))
    end

    # `bash -lc SCRIPT NAME ARGS` runs SCRIPT, the word after the option that holds `c`.
    def shell_script?(words) = SHELLS.include?(words.first.to_s) && !script(words).nil?

    def script(words)
      at = words.index { |word| word.match?(/\A-[a-z]*c[a-z]*\z/) }
      words[at + 1] if at
    end

    # A `shaka` command, or one run through a variable holding its path, is the helper unless it ran a check.
    def helper_category(arguments)
      operation = arguments.first(2).join(' ')
      return 'validation' if operation == 'evidence run'

      ['review run', 'post-implementation run'].include?(operation) ? 'review' : 'helper'
    end

    def validation?(program, arguments)
      return true if VALIDATION.include?(program)
      return arguments.include?('test') if TEST_RUNNERS.include?(program)

      program == 'ruby' && arguments.any? do |word|
        word.end_with?('_test.rb') || VALIDATION.include?(File.basename(word))
      end
    end
  end
end
