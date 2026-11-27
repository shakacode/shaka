# frozen_string_literal: true

require_relative '../error'
require_relative 'check'
require_relative 'checks'
require_relative 'installation_identity'
require_relative 'installation_state'
require_relative 'system'
require_relative '../startup_notice'

module Shaka
  class Doctor
    # The task-start check: where this Shaka runs from, whose settings the checkout holds, and
    # whether Ruby, gh, and the repository work. Like the full report, it writes only the mark
    # that doctor has run.
    class Brief
      include Check

      GUIDE = 'https://github.com/shakacode/shaka/blob/main/docs/getting-started.md#1-install-shaka'
      SKILL = File.expand_path('../../..', __dir__)
      # The workflow shows this report in the agent's first reply, so a user who skipped setup reads these
      # lines before anything else and does not mistake a task without settings for a full Shaka run.
      NOT_SET_UP = 'Shaka is not set up in this repository, so it cannot run its full workflow here yet.'
      NEXT_STEP = 'Next step: say "Set up Shaka just for me" to try it privately in this clone, or ' \
                  '"Configure this repository for Shaka" to open a team setup PR.'

      def self.run(arguments, options)
        refuse_extra!(arguments, options)
        root = File.realpath(options.fetch(:root, Dir.pwd))
        system = System.default
        checks = Checks.new(root:, host: nil, environment: ENV, system:).brief
        brief = new(checks:, installation_state: InstallationState.new(system:))
        puts brief.report
        StartupNotice::Marks.doctor_ran
        brief.blocked? ? 1 : 0
      end

      def self.refuse_extra!(arguments, options)
        raise OptionParser::InvalidArgument, arguments.join(' ') unless arguments.empty?
        raise OptionParser::InvalidArgument, '--brief takes only --root' unless (options.keys - %i[brief root]).empty?
      end
      private_class_method :refuse_extra!

      def initialize(checks:, installation_state:, identity: InstallationIdentity.method(:read), home: Dir.home)
        @checks = checks
        @installation_state = installation_state
        @identity = identity
        @home = home
      end

      def items = @items ||= [*installation_checks, *@checks]

      def report = [*not_set_up, "Shaka start check: #{worst.upcase}", *items.map { |item| render(item) }].join("\n")

      def blocked? = worst == 'failed'

      private

      def not_set_up = items.any? { |item| item[:settings_missing] } ? [NOT_SET_UP, NEXT_STEP, ''] : []

      def worst = items.map { |item| item.fetch(:status) }.max_by { |status| SEVERITY.fetch(status) }

      # A copied skill runs normally, so this line is the only place a user learns it gets no updates.
      def installation_checks
        identity = @identity.call
        place = "#{identity.fetch('version')} at #{location}"
        installed = installed(identity.fetch('source'))
        return [check('Installation', 'healthy', "#{place}, #{installed}"), *recovery_warnings] if installed

        [check('Installation', 'degraded', "#{place} was not set up by the Shaka installer and gets no update checks",
               guidance: "Install Shaka with the official installer: #{GUIDE}")]
      rescue Shaka::Error, KeyError, TypeError, SystemCallError => e
        [check('Installation', 'failed', first_line(e.message), guidance: "Reinstall Shaka: #{GUIDE}")]
      end

      def recovery_warnings
        state = @installation_state.call
        state.fetch(:status) == 'healthy' ? [] : [state]
      end

      def installed(source)
        case source['kind']
        when 'revision' then "revision #{source.fetch('revision')[0, 12]}"
        when 'development' then 'a development package'
        end
      end

      def location = SKILL.start_with?("#{@home}/") ? "~#{SKILL.delete_prefix(@home)}" : SKILL
    end
  end
end
