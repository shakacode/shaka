# frozen_string_literal: true

require_relative '../error'
require_relative 'paths'
require_relative 'personal_settings'

module Shaka
  module Configuration
    # What the user's ~/.agents/shaka/config.yml lets the PRs and issue comments they publish show.
    # It can only hide: a value the repository hides stays hidden whatever this file says. Every
    # publication reads it again, so an edit applies to the next update. A file that cannot be read
    # hides both values, because a broken privacy choice must not publish what it meant to hide.
    class PersonalPrivacy
      KEYS = %w[include_checkout_path include_chat_link].freeze
      BOOLEANS = [true, false].freeze
      REDACTION = 'REDACTED (personal setting)'

      # Nothing hidden when the file is absent or no home directory is known.
      def self.load(home: Dir.home)
        return new({}) if home.nil? || home.empty?

        path = File.join(home, Paths::PERSONAL_SETTINGS)
        return new({}, path:) if absent?(path)

        new(choices(path), path:)
      rescue Error, SystemCallError => e
        new(KEYS.to_h { [it, false] }, path:, warning: "#{e.message}. Hiding the checkout path and chat link " \
                                                       'on publications until the file is fixed.')
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

      def self.choices(path)
        wip = PersonalSettings.read(path)['wip']
        return {} if wip.nil?
        raise Error, "#{path} wip must be a mapping" unless wip.is_a?(Hash)

        KEYS.each do |key|
          raise Error, "#{path} wip.#{key} must be true or false" if wip.key?(key) && !BOOLEANS.include?(wip[key])
        end
        wip.slice(*KEYS)
      end

      attr_reader :path, :warning

      def initialize(choices, path: nil, warning: nil)
        @choices = choices
        @path = path
        @warning = warning
      end

      def checkout_path? = @choices['include_checkout_path'] != false
      def chat_link? = @choices['include_chat_link'] != false

      # The content with its WIP chat link withheld when the user hides it. A malformed disclosure is
      # left for the renderer to refuse.
      def apply(content)
        return content if chat_link? || !content.is_a?(Hash) || !content['wip'].is_a?(Hash)

        disclosure = content['wip_disclosure']
        return content unless disclosure.nil? || disclosure.is_a?(Hash)

        content.merge('wip' => content['wip'].merge('thread' => 'UNKNOWN'),
                      'wip_disclosure' => (disclosure || {}).merge('thread' => 'withheld'))
      end

      # What this user's publications show in a repository, and which choice hides each value.
      def report(repository_shows_checkout_path:)
        path = if !repository_shows_checkout_path then 'hidden by the repository setting'
               elsif checkout_path? then 'shown'
               else 'hidden by your personal file'
               end
        { 'personal_file' => @path, 'checkout_path' => path,
          'chat_link' => chat_link? ? 'shown when the host has a link' : 'hidden by your personal file',
          'warning' => @warning }.compact
      end
    end
  end
end
