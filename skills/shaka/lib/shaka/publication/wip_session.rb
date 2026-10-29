# frozen_string_literal: true

require_relative '../error'
require_relative '../doctor/machine_alias'
require_relative '../hosts/codex_wake'

module Shaka
  # Field-by-field comparison of a supplied WIP value with the calling session.
  module WipFieldChecks
    def check_alias(published)
      return withheld('machine alias', published) if withheld?('alias')

      refuse_machine_name(published)
      compare_alias(published, Doctor::MachineAlias.observation(@environment, host_name: @host_name))
    end

    def check_host(published)
      return withheld('host', published) if withheld?('host')

      label = host_label
      return carried('host', published, 'host') unless label
      return 'available' if published == label || published.start_with?("#{label} ")

      refuse(host_refusal(published, label))
    end

    def check_tag(published)
      return withheld('owner tag', published) if withheld?('tag')
      return 'available' unless published == 'UNKNOWN'

      carried('tag', published, 'owner tag')
    end

    def check_thread(published)
      refuse(WipSession.share_message) if WipSession.share_link?(published)
      return withheld('chat link', published) if withheld?('thread')

      compare_thread(published, thread_observation)
    end

    def compare_alias(published, observed)
      case observed.fetch('disposition')
      when 'available' then available_alias(published, observed.fetch('value'))
      when 'invalid' then unknown_only(published, 'invalid', alias_invalid)
      when 'withheld' then unknown_only(published, 'withheld', alias_withheld)
      else carried('alias', published, 'machine alias')
      end
    end

    def available_alias(published, value)
      refuse('WIP machine alias was available but was not collected. Publish it, or withhold it.') if
        published == 'UNKNOWN'
      return 'available' if published == value

      refuse("WIP machine alias does not match the collected public alias `#{value}`.")
    end

    def compare_thread(published, observed)
      case observed.fetch('disposition')
      when 'available' then available_thread(published, observed.fetch('value'))
      when 'invalid' then unknown_only(published, 'invalid', thread_invalid)
      else carried('thread', published, 'chat link')
      end
    end

    def available_thread(published, locator)
      if published == 'UNKNOWN'
        refuse('WIP chat link was available in the calling Codex session but was not collected. ' \
               'Publish the local codex://threads locator, or withhold the field.')
      end
      return 'available' if published == locator

      refuse('WIP chat link does not match the collected local Codex chat locator.')
    end

    # A value the session cannot observe was still published, so handoff must defend it. Only the
    # owner that published it carries it over; a takeover under a new tag starts fresh.
    def carried(field, published, label)
      return 'available' unless published == 'UNKNOWN'

      if earlier?(field) && same_owner?
        refuse("WIP #{label} was collected earlier and is now UNKNOWN. Publish it again, or withhold it.")
      end

      'unavailable'
    end

    def unknown_only(published, disposition, message)
      refuse(message) unless published == 'UNKNOWN'

      disposition
    end

    def withheld(label, published)
      refuse("WIP #{label} was withheld and must stay UNKNOWN.") unless published == 'UNKNOWN'

      'withheld'
    end

    def refuse_machine_name(published)
      return if published == 'UNKNOWN'
      return unless Doctor::MachineAlias.machine_name?(@environment, published, host_name: @host_name)

      refuse("WIP machine alias is this machine's own name. Publish UNKNOWN or a public alias.")
    end

    def host_refusal(published, label)
      return "WIP host was available (#{label}) but was not collected." if published == 'UNKNOWN'

      "WIP host does not match the collected coding host (#{label})."
    end

    def alias_invalid = 'WIP machine alias is not a public-safe token. Publish UNKNOWN.'

    def alias_withheld = 'WIP machine alias names this machine and is omitted. Publish UNKNOWN.'

    def thread_invalid = 'WIP chat link uses a Codex thread id that is not a UUID. Publish UNKNOWN.'

    def refuse(message) = raise Error, message
  end

  # Reads the calling session and decides whether each WIP field was collected.
  class WipSession
    include WipFieldChecks

    FIELDS = %w[alias host tag thread].freeze
    HOSTS = { 'CODEX_THREAD_ID' => 'Codex', 'CLAUDE_CODE_SESSION_ID' => 'Claude Code',
              'CURSOR_CONVERSATION_ID' => 'Cursor', 'OPENCODE_SESSION_ID' => 'OpenCode' }.freeze
    SHARE = %r{(?:^|[/:.?&#])(?:share|export)(?:$|[/:.?&#])}i
    OPENAI_CHAT = %r{\Ahttps?://(?:www\.)?(?:chatgpt\.com|chat\.openai\.com)(?:/|\z)}i

    def self.share_link?(value)
      text = value.to_s
      text != 'UNKNOWN' && (text.match?(SHARE) || text.match?(OPENAI_CHAT))
    end

    def self.share_message
      'WIP chat link would publish conversation content. Use the local codex://threads locator, ' \
        'or UNKNOWN when the user withholds it.'
    end

    def initialize(owner, thread, session)
      @owner = owner
      @thread = thread
      @environment = session[:environment] || {}
      @previous = session[:previous] || {}
      @host_name = session[:host_name] || Doctor::MachineAlias.system_name
      @disclosure = disclosure(session[:disclosure])
    end

    def dispositions
      FIELDS.to_h { |field| [field, send(:"check_#{field}", current(field))] }
    end

    private

    def current(field)
      return @thread if field == 'thread'

      parts = @owner == 'UNKNOWN' ? %w[UNKNOWN UNKNOWN UNKNOWN] : @owner.split('·', -1).map(&:strip)
      parts[FIELDS.index(field)]
    end

    def earlier?(field)
      value = field == 'thread' ? @previous['thread'] : previous_part(field)
      value.is_a?(String) && !value.empty? && value != 'UNKNOWN'
    end

    def same_owner?
      tag = current('tag')
      tag == 'UNKNOWN' || tag == previous_part('tag')
    end

    def previous_part(field)
      owner = @previous['owner']
      parts = owner == 'UNKNOWN' ? [] : owner.to_s.split('·', -1).map(&:strip)
      parts[FIELDS.index(field)] if parts.length == 3 && parts.none?(&:empty?)
    end

    def host_label
      names = HOSTS.filter_map { |variable, label| label unless @environment[variable].to_s.empty? }
      names << 'Pi' if @environment['PI_CODING_AGENT'] == 'true'
      names.first if names.one?
    end

    def thread_observation
      id = @environment['CODEX_THREAD_ID'].to_s
      return { 'disposition' => 'unavailable' } if host_label != 'Codex' || id.empty?
      return { 'disposition' => 'invalid' } unless id.match?(CodexWake::THREAD)

      { 'disposition' => 'available', 'value' => "codex://threads/#{id}" }
    end

    def withheld?(field) = @disclosure[field] == 'withheld'

    def disclosure(spec)
      return {} if spec.nil?
      raise Error, 'Publication wip_disclosure must be an object.' unless spec.is_a?(Hash)

      extra = spec.keys - FIELDS
      raise Error, "Publication wip_disclosure has unknown fields: #{extra.join(', ')}." unless extra.empty?

      spec.each { |field, value| refuse_disclosure(field) unless value == 'withheld' }
      spec
    end

    def refuse_disclosure(field)
      raise Error, "Publication wip_disclosure #{field} must be withheld."
    end
  end
end
