# frozen_string_literal: true

require 'shellwords'
require_relative 'official'
require_relative 'status_git'
require_relative 'status_revision'
require_relative 'checkout_development'
require_relative 'settings_location'
require_relative 'status_modes'
require_relative 'status_states'

module Shaka
  module Install
    # Reads one registered checkout's Git state without changing it or reaching the network.
    class StatusCheckout
      include StatusGit
      include StatusRevision
      include CheckoutDevelopment

      include StatusModes

      attr_reader :root, :record

      def initialize(root, record)
        @root = root
        @record = record
        @branch = record['branch']
        @release = record['release']
      end

      def helper = command(File.join(@root, 'skills/shaka/scripts/shaka'))
      def installer = command(File.join(@root, 'bin/install'))

      # bin/install refuses a checkout that hosts development, so steps that run it wait for that move. The
      # safety check comes first: Git reads a writable checkout's config, which can name commands.
      def development?
        unsafe.nil? && development_uses.any?
      rescue ArgumentError
        false
      end

      # Git reads a writable checkout's config, which can name commands to run, so an unsafe
      # checkout gets no Git read at all, as the installer refuses it before any Git command.
      def findings
        safety = unsafe
        return [safety] if safety

        [unsafe_files, origin, branch, dirty, changed_contents, revision, pending, ruby, development].compact
      end

      private

      def origin
        actual = value('config', '--get', 'remote.origin.url')
        return if actual == @record['repository']

        expected = @record['repository']
        detail = "origin is #{actual ? StatusStates.redact(actual) : 'missing'}; " \
                 "the record expects #{StatusStates.redact(expected)}"
        return finding('B5', detail, decision: 'Restore the origin URL saved in .git/shaka-install.json.') if
          StatusStates.credentials?(expected)

        finding('B5', detail, command: "#{git_command} remote set-url origin #{command(expected)}")
      end

      def dirty
        # Without --no-optional-locks, status refreshes the index, and a read-only report must not write.
        changes = value('--no-optional-locks', 'status', '--porcelain', '--untracked-files=all').to_s
        files = changes.lines.map { |line| line[3..].strip }
        return if files.empty?

        finding('B3', "uncommitted files: #{listed(files)}",
                decision: 'Keep or discard these edits yourself; move kept work to a development checkout.')
      end

      def pending
        target = @record['pending_revision']
        return unless target

        finding('B7', "an update to #{target[0, 7]} did not finish", command: "#{installer} --update")
      end

      def ruby
        path = File.join(@root, '.git', Official::RUBY_RECORD)
        recorded = File.file?(path) ? File.read(path).strip : nil
        return if recorded && File.executable?(recorded)

        finding('B8', "recorded Ruby #{recorded || 'is missing'}#{' is unavailable' if recorded}; " \
                      'run the next command with Ruby 3.4 or later first on PATH',
                command: ruby_step)
      rescue SystemCallError => e
        finding('B8', "recorded Ruby cannot be read: #{e.message}", command: ruby_step)
      end

      # A plain install refuses a checkout used for development; an update only warns, and also records Ruby.
      def ruby_step = development? ? "#{installer} --update" : installer

      # The installer's own check, so status and installation agree on what counts as development.
      # Moving development out fixes nothing broken, so it ranks after the install's own problems.
      def development
        uses = development_uses
        return if uses.empty?

        finding('C3', "source checkout is also used for development (#{uses.join('; ')})", **development_step)
          .merge('rank' => 'C3-development')
      rescue ArgumentError
        nil
      end

      # --take-over cannot move the hosts to the checkout they already use, and an occupied default
      # location gets the same answer the installer gives for it.
      def development_step
        home = Dir.home
        if @root == real(SettingsLocation.default_directory(home))
          return { decision: 'Move these worktrees and branches to a separate development clone; this checkout ' \
                             'already sits where a fresh Shaka checkout would go.' }
        end

        command = SettingsLocation.take_over(@root, home, @record)
        command ? { command: } : { decision: SettingsLocation.decision(home) }
      end

      def real(path)
        File.realpath(path)
      rescue SystemCallError
        nil
      end

      def git_command = "git -C #{command(@root)}"
      def command(text) = Shellwords.escape(text)

      def finding(id, detail, **) = StatusStates.finding(id, @root, detail, **)
    end
  end
end
