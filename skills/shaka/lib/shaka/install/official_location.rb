# frozen_string_literal: true

require_relative 'settings_location'

module Shaka
  module Install
    # Keeps the source checkout out of the settings location and says where an install put everything.
    module OfficialLocation
      private

      def selected_directory(source, options)
        options[:directory] || (source if options[:take_over]) || registered_source(source) ||
          File.join(Dir.home, Locations::SOURCE)
      end

      # Runs before anything touches the destination, so a refused --directory leaves no folder behind.
      def refuse_settings_location(selected, source, options)
        root = SettingsLocation.resolved(selected)
        return unless SettingsLocation.inside?(root, Dir.home)

        state = "Installation checkout is under #{File.join(Dir.home, Locations::SETTINGS)}, where Shaka keeps " \
                'settings, not source'
        raise ArgumentError, old_install(state, root) if registered?(root)

        raise ArgumentError, Refusal.message(state, root, fresh_command(source, options))
      end

      # An unreadable record names no custom folder; the take-over itself reports the record problem.
      def recorded(root)
        Checkout.new(root).read_record
      rescue ArgumentError
        nil
      end

      def registered?(root) = File.file?(File.join(root, '.git', Checkout::RECORD))

      def old_install(state, root)
        command = SettingsLocation.take_over(root, Dir.home, recorded(root))
        Refusal.message("#{state}; this location is no longer supported", root,
                        command || SettingsLocation.decision(Dir.home),
                        note: 'The take-over leaves this checkout in place; delete it afterward')
      end

      # The same selections, installed into the default location instead.
      def fresh_command(source, options)
        towers = @names.filter_map { |name| SettingsLocation::TOWERS[name] }.uniq
        Refusal.command(File.join(source, 'bin/install'), '--directory', SettingsLocation.default_directory(Dir.home),
                        *selections(options), *@agents.flat_map { |agent| ['--agent', agent] }, *towers,
                        *('--take-over' if options[:take_over]), *('--session-hook' if options[:session_hook]))
      end

      def selections(options)
        values = { '--repository' => options[:repository] && Refusal.url(options[:repository]),
                   '--branch' => options[:branch], '--skills-dir' => options[:skills_dir] }
        values.compact.flat_map { |flag, value| [flag, value] }
      end

      def location_summary
        directories = @checkout.record.fetch('targets').map { |target| target.fetch('directory') }
        puts "Source checkout: #{@checkout.root} at #{@checkout.revision[0, 7]} (Shaka source, not configuration)"
        puts "Skills folders: #{directories.join(', ')}"
        puts "Settings: each project's #{File.join(Locations::SETTINGS, 'shaka', '')} and " \
             "~/#{File.join(Locations::SETTINGS, 'trusted-github-actors.yml')}"
      end
    end
  end
end
