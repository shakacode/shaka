# frozen_string_literal: true

require_relative '../error'
require_relative 'paths'
require_relative 'personal_settings'

module Shaka
  module Configuration
    # Whether the user's ~/.agents/shaka/config.yml lets the PRs and issue comments they publish show
    # their checkout path. It can only hide: a path the repository hides stays hidden whatever this
    # file says. Every publication reads it again, so an edit applies to the next update. A file that
    # cannot be read hides the path, because a broken privacy choice must not publish what it meant
    # to hide.
    class PersonalPrivacy
      KEY = 'include_checkout_path'
      REDACTION = 'REDACTED (personal setting)'

      # Nothing hidden when the file is absent or no home directory is known.
      def self.load(home: Dir.home)
        return new(nil) if home.nil? || home.empty?

        path = File.join(home, Paths::PERSONAL_SETTINGS)
        return new(nil, path:) if absent?(path)

        new(choice(path), path:)
      rescue Error, SystemCallError => e
        new(false, path:, warning: "#{e.message}. Hiding the checkout path on publications until the file is fixed.")
      end

      # Only a missing file or folder is absent. A folder Shaka cannot open, a file where a folder
      # belongs, or a link to a missing target such as an unmounted dotfiles volume, hides the file,
      # not the choice.
      def self.absent?(path)
        File.stat(path)
        false
      rescue Errno::ENOENT
        [path, File.dirname(path), File.dirname(path, 2)].none? { File.symlink?(it) && !File.exist?(it) }
      end

      def self.choice(path)
        wip = PersonalSettings.read(path)['wip']
        return if wip.nil?
        raise Error, "#{path} wip must be a mapping" unless wip.is_a?(Hash)
        raise Error, "#{path} wip.#{KEY} must be true or false" if wip.key?(KEY) && ![true, false].include?(wip[KEY])

        wip[KEY]
      end

      attr_reader :path, :warning

      def initialize(choice, path: nil, warning: nil)
        @choice = choice
        @path = path
        @warning = warning
      end

      def checkout_path? = @choice != false

      # What this user's publications show in a repository, and which choice hides the path.
      def report(repository_shows_checkout_path:)
        shown = if !repository_shows_checkout_path then 'hidden by the repository setting'
                elsif checkout_path? then 'shown'
                else 'hidden by your personal file'
                end
        { 'personal_file' => @path, 'checkout_path' => shown, 'warning' => @warning }.compact
      end
    end
  end
end
