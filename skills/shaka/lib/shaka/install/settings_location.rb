# frozen_string_literal: true

require_relative 'locations'
require_relative 'refusal'

module Shaka
  module Install
    # The settings folder in HOME holds Shaka settings, so a source checkout there is refused with the one
    # command that moves its links to a checkout in the default location. Nothing is migrated: the old
    # checkout stays for the user. The refusal is fixed, with no override: ADR 0002 keeps an install out of
    # a location that has no supported path once compatibility code is removed.
    module SettingsLocation
      TOWERS = { 'rct' => '--with-rct', 'mct' => '--with-mct', 'mct-claude' => '--with-claude-towers',
                 'rct-claude' => '--with-claude-towers' }.freeze

      module_function

      def default_directory(home) = File.join(home, Locations::SOURCE)

      def inside?(path, home)
        settings = File.join(home, Locations::SETTINGS)
        [File.expand_path(path), resolved(path)].any? do |candidate|
          [settings, resolved(settings)].any? { |root| candidate == root || candidate.start_with?("#{root}/") }
        end
      end

      # A folder the installer would create resolves through its nearest existing parent, so a symbolic
      # link to the settings folder cannot hide it.
      def resolved(path)
        path = File.expand_path(path)
        missing = []
        until (found = real(path)) || File.dirname(path) == path
          missing.unshift(File.basename(path))
          path = File.dirname(path)
        end
        File.join(found || path, *missing)
      end

      # The registered checkout's own installer clones its recorded origin and branch into the default
      # location and moves every host link there. An install already registered at the default location
      # takes the links over itself when it follows the same origin and branch; any other occupied default
      # location needs a person.
      def take_over(root, home, record)
        target = default_directory(home)
        if File.file?(File.join(target, '.git', Locations::RECORD))
          return unless same_source?(target, record)

          return Refusal.command(File.join(target, 'bin/install'), '--take-over', *custom_folder(record, home))
        end
        return if File.exist?(target) && !(File.directory?(target) && Dir.empty?(target))

        Refusal.command(File.join(root, 'bin/install'), '--directory', target, '--take-over')
      end

      # Recovery keeps the old source selection; different releases need an explicit version change.
      def same_source?(target, record)
        return true unless record

        current = Checkout.new(target).read_record
        current && %w[repository branch release].all? { |key| current[key] == record[key] }
      rescue ArgumentError
        false
      end

      # The default install finds the old checkout through its links; a custom folder has to be named.
      def custom_folder(record, home)
        return [] unless record

        hosts = Locations::HOSTS.values.flat_map { |directory| spellings(File.join(home, directory)) }
        custom = record.fetch('targets').map { |target| target.fetch('directory') }
                       .reject { |directory| spellings(directory).intersect?(hosts) }
        custom.empty? ? [] : ['--skills-dir', custom.first]
      end

      # A host folder can be recorded through a symbolic link to HOME, so both forms name it.
      def spellings(path) = [File.expand_path(path), real(path)].compact

      def decision(home)
        "a person must decide what to do with #{default_directory(home)}, which already exists; move it aside, " \
          'then run this checkout\'s bin/install --directory with that path and --take-over'
      end

      def real(path)
        File.realpath(path)
      rescue SystemCallError
        nil
      end
    end
  end
end
