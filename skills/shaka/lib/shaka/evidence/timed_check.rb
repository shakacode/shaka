# frozen_string_literal: true

require 'open3'
require_relative '../call_log'
require_relative '../error'
require_relative '../executable_file'
require_relative 'machine_facts'
require_relative 'phase_log'
require_relative 'tree_watch'
require_relative 'trusted_command'

module Shaka
  module Evidence
    # Runs a fixed command while watching the tested tree, and returns its outcome with how long it took,
    # on what machine, and the phases and failing test classes the command reported into the file its
    # environment names.
    module TimedCheck
      module_function

      def run(context, tree, path:, arguments:)
        (outcome, timing), reported = PhaseLog.with_file do |log|
          command = command(context, { 'PATH' => path, PhaseLog::VARIABLE => log }, arguments)
          TrustedCommand.around(context, tree) do |root, watched|
            MachineFacts.measure { CallLog.measure { TreeWatch.new(command, root:, tree: watched).run } }
          end
        end
        measured = { 'phases' => CallLog.phases(reported['phases']),
                     'failed_tests' => CallLog.failed_tests(reported['failed_tests']) }
        [outcome, timing.merge(measured.compact)]
      end

      def command(context, environment, arguments)
        script = File.join(*context.values_at(:root, :path))
        [environment, *ExecutableFile.script_command(script, shell: method(:git_shell)), *arguments]
      end

      # Git for Windows keeps git-core under ROOT/<mingw dir>/libexec and sh.exe under ROOT/usr/bin. The
      # git comes from PATH, which evidence run has already guarded against the candidate checkout.
      def git_shell
        output, status = Open3.capture2('git', '--exec-path')
        raise Error, 'Cannot find Git for Windows: git --exec-path failed' unless status.success?

        git_root = File.expand_path('../../..', output.strip)
        shell = %w[usr/bin/sh.exe bin/sh.exe].map { File.join(git_root, it) }.find { File.file?(it) }
        shell || raise(Error, "Cannot find sh.exe from Git for Windows under #{git_root}")
      end
    end
  end
end
