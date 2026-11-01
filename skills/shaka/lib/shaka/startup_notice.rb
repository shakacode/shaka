# frozen_string_literal: true

require 'shellwords'
require 'time'
require_relative 'configuration/layout'
require_relative 'install/locations'
require_relative 'update_check/cache'
require_relative 'startup_notice/marks'

module Shaka
  # Prints at most one stderr line when a helper call starts: a host link names a different
  # installation, the cached update check says this installation needs attention, the
  # repository has no Shaka settings, or doctor has never run on this machine. It reads local
  # files only, never the network, and a failure never changes the command's result.
  class StartupNotice
    VARIABLE = 'SHAKA_NOTICES'
    ROOT = File.expand_path('../../../..', __dir__)
    # update-check prints its own answer, and install reports the installation it changes.
    SKIPPED = %w[install update-check].freeze
    # Doctor reports settings and its own run, and seam is the setup the settings reminder asks for.
    QUIET = %w[doctor seam].freeze
    ACTIONABLE = %w[available drift].freeze
    SETUP_GUIDE = 'https://github.com/shakacode/shaka/blob/main/docs/getting-started.md#2-choose-individual-or-team-setup'

    def self.call(arguments, env: ENV, output: $stderr)
      return if env[VARIABLE] == 'off' || arguments.empty? || SKIPPED.include?(arguments.first)

      line = new(home: Dir.home, repository: repository(arguments), command: arguments.first).line
      output.puts("shaka: #{line}") if line
    rescue StandardError => e
      output.puts("shaka: notice skipped: #{e.message}")
    end

    # Claude Code adds a SessionStart hook's plain-text output to the new chat, but not a JSON answer.
    # Only the saved answer is read, so a new chat never waits on the network.
    def self.session_start(output: $stdout, home: nil, root: ROOT, now: Time.now)
      line = new(home: home || Dir.home, root:, now:).saved_update
      output.puts("Shaka update check: #{line}") if line
      0
    rescue StandardError
      0
    end

    # The checkout a call works in: its --root, or the current directory, up to the nearest .git.
    def self.repository(arguments)
      index = arguments.index('--root')
      given = index ? arguments[index + 1] : arguments.find { it.start_with?('--root=') }&.delete_prefix('--root=')
      directory = File.expand_path(given || Dir.pwd)
      loop do
        return File.realpath(directory) if File.exist?(File.join(directory, '.git'))
        return if File.dirname(directory) == directory

        directory = File.dirname(directory)
      end
    end

    def initialize(home:, root: ROOT, now: Time.now, repository: nil, command: nil)
      @home = home
      @root = root
      @now = now
      @repository = repository
      @command = command
    end

    def line
      other_installation || update || (missing_settings || doctor_unrun unless QUIET.include?(@command))
    end

    # What the saved answer asks of a registered checkout, without the once-a-day limit.
    def saved_update = (update_line(UpdateCheck::Cache.read(@root, home: @home)) if registered?)

    private

    # A PR trial package runs on purpose beside the linked installation, so it gets no notice.
    def other_installation
      return if File.file?(File.join(@root, '.shaka-install.json'))

      own = File.realpath(File.join(@root, 'skills/shaka'))
      linked = host_links
      return if linked.empty? || linked.any? { |_link, skill| skill == own }

      link, skill = linked.first
      "This helper runs from #{@root}, but #{link} links to #{File.dirname(skill, 2)}. " \
        "Use #{Shellwords.escape(File.join(skill, 'scripts/shaka'))}."
    end

    def host_links
      Install::Locations::HOSTS.values.filter_map do |directory|
        link = File.join(@home, directory, 'shaka')
        [link, File.realpath(link)] if File.symlink?(link) && File.exist?(link)
      end
    end

    # Only a registered checkout has update answers; one notice at most per day.
    def update
      return unless registered?

      entry = UpdateCheck::Cache.read(@root, home: @home)
      return if UpdateCheck::Cache.fresh?(entry['noticed_at'], @now)

      line = update_line(entry)
      line if line && UpdateCheck::Cache.noticed(entry, @root, home: @home, now: @now)
    end

    # Private trial settings sit in the working tree like team settings, so either silences this.
    def missing_settings
      return if @repository.nil? || settings?

      reminder("settings #{@repository}",
               "#{@repository} has no Shaka settings (#{Configuration::Paths::CONTRACT}). Unless the user " \
               "already chose, ask for a private trial in this clone or team setup: #{SETUP_GUIDE}. " \
               'Declining setup skips settings, not the publication steps.')
    end

    def settings?
      Configuration::Layout.entry?(File.join(@repository, Configuration::Paths::CONTRACT))
    end

    def doctor_unrun
      return if Marks.doctor_ran?(@home)

      reminder('doctor', 'Shaka doctor has not run on this machine. ' \
                         "Run #{Shellwords.escape(helper)} doctor --brief --root DIR to check this setup.")
    end

    def reminder(key, text)
      return if Marks.shown_today?(key, home: @home, now: @now)

      text if Marks.show(key, home: @home, now: @now)
    end

    def helper = File.join(@root, 'skills/shaka/scripts/shaka')

    def registered? = File.file?(File.join(@root, '.git', Install::Locations::RECORD))

    def update_line(entry)
      result = entry['result']
      unless result.is_a?(Hash) && UpdateCheck::Cache.fresh?(entry['checked_at'], @now)
        return "Shaka has not checked for updates in the last day. Run #{Shellwords.escape(helper)} update-check."
      end

      result['guidance'] if ACTIONABLE.include?(result['status'])
    end
  end
end
