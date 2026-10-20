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
        [File.expand_path(path), real(path)].compact.any? do |candidate|
          [settings, real(settings)].compact.any? { |root| candidate == root || candidate.start_with?("#{root}/") }
        end
      end

      # The registered checkout's own installer clones its recorded origin and branch into the default
      # location and moves every host link there. An install already registered at the default location
      # takes the links over itself; any other occupied default location needs a person.
      def take_over(root, home)
        target = default_directory(home)
        return Refusal.command(File.join(target, 'bin/install'), '--take-over') if
          File.file?(File.join(target, '.git', Locations::RECORD))
        return if File.exist?(target) && !(File.directory?(target) && Dir.empty?(target))

        Refusal.command(File.join(root, 'bin/install'), '--directory', target, '--take-over')
      end

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
