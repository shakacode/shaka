# frozen_string_literal: true

require 'open3'
require_relative '../call_log'
require_relative '../error'
require_relative '../executable_file'
require_relative '../local_review/executable'
require_relative '../local_review/path_guard'
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
        root = context.fetch(:root)
        script = File.join(root, context.fetch(:path))
        [environment, *ExecutableFile.script_command(script, shell: -> { git_shell(root) }), *arguments]
      end

      # Git for Windows keeps git-core under GIT/<mingw dir>/libexec and its sh under GIT/bin, whose sh
      # puts Git's Unix tools on PATH. git.exe comes by full path from a PATH entry outside the
      # candidate CHECKOUT, so a git.exe in the current directory or one the checkout put on PATH
      # cannot answer, and an inherited GIT_EXEC_PATH cannot move the root.
      def git_shell(checkout)
        git = LocalReviewPathGuard.safe_executable(ENV.fetch('PATH', ''), 'git.exe', checkout)
        raise Error, 'Cannot find git.exe outside the checkout on PATH' unless git

        output, status = Open3.capture2({ 'GIT_EXEC_PATH' => nil }, git, '--exec-path')
        raise Error, 'Cannot find Git for Windows: git --exec-path failed' unless status.success?

        trusted_shell(File.expand_path('../../..', output.strip), checkout)
      end

      # The sh is held to the same boundary as git.exe: one that resolves into the checkout is refused.
      def trusted_shell(git_root, checkout)
        shell = %w[bin/sh.exe usr/bin/sh.exe].map { File.join(git_root, it) }.find { File.file?(it) }
        raise Error, "Cannot find sh.exe from Git for Windows under #{git_root}" unless shell
        return shell unless LocalReviewExecutable.candidate_owned?(File.realpath(shell), File.realpath(checkout))

        raise Error, "sh.exe under #{git_root} resolves inside the checkout"
      end
    end
  end
end
