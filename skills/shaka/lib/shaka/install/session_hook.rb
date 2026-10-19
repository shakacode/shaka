# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'shellwords'
require_relative 'official'

module Shaka
  module Install
    # Adds or removes the Claude Code SessionStart hook that runs update-check when a chat starts,
    # so its answer reaches the chat without relying on the agent. Other settings stay unchanged.
    class SessionHook
      SETTINGS = '.claude/settings.json'
      # Any Shaka checkout's hook matches, so a reinstall from a moved checkout replaces the old entry.
      OWNED = %r{skills/shaka/scripts/shaka update-check\z}

      # Each installation chooses again, so installing without --session-hook removes an earlier hook.
      # The hook runs the helper behind the Claude Code skill link, which the installation just set.
      def self.choose(enabled, home: Dir.home)
        skill = File.realpath(File.join(home, Official::HOSTS.fetch('claude'), 'shaka')) if enabled
        change = new(skill && File.join(skill, 'scripts/shaka'), home:).apply(enabled)
        puts change if change
      end

      def initialize(helper, home: Dir.home)
        @command = "#{Shellwords.escape(helper)} update-check" if helper
        @path = File.join(home, SETTINGS)
      end

      # Returns the change made, or nil when the settings already match.
      def apply(enabled)
        settings = read(strict: enabled)
        return if settings.nil? || owned_commands(settings) == (enabled ? [@command] : [])

        remove_owned(settings)
        add(settings) if enabled
        write(settings)
        "#{enabled ? 'Set' : 'Removed'} the Claude Code update-check hook in #{@path}"
      end

      private

      # Without the flag, settings Shaka cannot read hold no hook it could remove, so they stay untouched.
      def read(strict:)
        return {} unless File.exist?(@path)

        settings = JSON.parse(File.read(@path))
        return settings if settings.is_a?(Hash) && hooks_shape?(settings['hooks'])

        refuse('does not hold a JSON object with a hooks object') if strict
      rescue JSON::ParserError => e
        refuse("is not valid JSON (#{e.message.lines.first.strip})") if strict
      end

      def hooks_shape?(hooks)
        hooks.nil? || (hooks.is_a?(Hash) && (hooks['SessionStart'].nil? || hooks['SessionStart'].is_a?(Array)))
      end

      def refuse(problem)
        raise ArgumentError, "Claude Code settings #{@path} #{problem}. Fix that file, " \
                             'or rerun bin/install without --session-hook.'
      end

      def owned_commands(settings)
        groups(settings).flat_map { |group| group_hooks(group).select { |hook| owned?(hook) } }.map { it['command'] }
      end

      def groups(settings) = settings.dig('hooks', 'SessionStart') || []
      def group_hooks(group) = group.is_a?(Hash) && group['hooks'].is_a?(Array) ? group['hooks'] : []

      # Groups left empty by the removal are dropped, and so are emptied hook tables.
      def remove_owned(settings)
        return if owned_commands(settings).empty?

        kept = groups(settings).filter_map do |group|
          hooks = group_hooks(group).reject { |hook| owned?(hook) }
          next group if hooks.size == group_hooks(group).size

          group.merge('hooks' => hooks) unless hooks.empty?
        end
        replace_groups(settings, kept)
      end

      def owned?(hook) = hook.is_a?(Hash) && hook['command'].is_a?(String) && hook['command'].match?(OWNED)

      def replace_groups(settings, groups)
        hooks = settings['hooks']
        groups.empty? ? hooks.delete('SessionStart') : hooks['SessionStart'] = groups
        settings.delete('hooks') if hooks.empty?
      end

      def add(settings)
        hooks = settings['hooks'] ||= {}
        (hooks['SessionStart'] ||= []) << { 'matcher' => 'startup',
                                            'hooks' => [{ 'type' => 'command', 'command' => @command }] }
      end

      # Writes beside the real file, so a settings link kept in a dotfiles repository stays a link.
      def write(settings)
        target = File.exist?(@path) ? File.realpath(@path) : @path
        FileUtils.mkdir_p(File.dirname(target), mode: 0o700)
        mode = File.exist?(target) ? File.stat(target).mode & 0o777 : 0o600
        temporary = "#{target}.shaka-#{Process.pid}"
        File.write(temporary, "#{JSON.pretty_generate(settings)}\n", mode: 'wx', perm: mode)
        File.rename(temporary, target)
      ensure
        File.unlink(temporary) if temporary && File.exist?(temporary)
      end
    end
  end
end
