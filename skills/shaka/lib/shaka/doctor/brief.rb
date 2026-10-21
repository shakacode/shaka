# frozen_string_literal: true

require_relative '../error'
require_relative 'check'
require_relative 'checks'
require_relative 'installation_identity'
require_relative 'system'

module Shaka
  class Doctor
    # The task-start check: where this Shaka runs from, whose settings the checkout holds, and
    # whether Ruby, gh, and the repository work. Read-only, like the full report.
    class Brief
      include Check

      GUIDE = 'https://github.com/shakacode/shaka/blob/main/docs/getting-started.md#1-install-shaka'
      SKILL = File.expand_path('../../..', __dir__)

      def self.run(arguments, options)
        refuse_extra!(arguments, options)
        root = File.realpath(options.fetch(:root, Dir.pwd))
        brief = new(checks: Checks.new(root:, host: nil, environment: ENV, system: System.default).brief)
        puts brief.report
        brief.blocked? ? 1 : 0
      end

      def self.refuse_extra!(arguments, options)
        raise OptionParser::InvalidArgument, arguments.join(' ') unless arguments.empty?
        raise OptionParser::InvalidArgument, '--brief takes only --root' unless (options.keys - %i[brief root]).empty?
      end
      private_class_method :refuse_extra!

      def initialize(checks:, identity: InstallationIdentity.method(:read), home: Dir.home)
        @checks = checks
        @identity = identity
        @home = home
      end

      def items = @items ||= [installation, *@checks]

      def report = ["Shaka start check: #{worst.upcase}", *items.map { |item| render(item) }].join("\n")

      def blocked? = worst == 'failed'

      private

      def worst = items.map { |item| item.fetch(:status) }.max_by { |status| SEVERITY.fetch(status) }

      # A copied skill runs normally, so this line is the only place a user learns it gets no updates.
      def installation
        identity = @identity.call
        place = "#{identity.fetch('version')} at #{location}"
        installed = installed(identity.fetch('source'))
        return check('Installation', 'healthy', "#{place}, #{installed}") if installed

        check('Installation', 'degraded', "#{place} was not set up by the Shaka installer and gets no update checks",
              guidance: "Install Shaka with the official installer: #{GUIDE}")
      rescue Shaka::Error, KeyError, TypeError, SystemCallError => e
        check('Installation', 'failed', first_line(e.message), guidance: "Reinstall Shaka: #{GUIDE}")
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
