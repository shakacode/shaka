# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative 'error'

module Shaka
  # Decides whether an intake already supplies the implementation checkpoint.
  class Checkpoint
    VALUE_ACTION = 'Accept or reject the value stated above, then reply ready.'

    def self.run(arguments)
      path = content_path(arguments)
      return 0 unless path

      puts JSON.generate(new(content(path)).result)
      0
    rescue OptionParser::ParseError, JSON::ParserError, SystemCallError, Shaka::Error => e
      warn "shaka: #{e.message}"
      1
    end

    def self.content_path(arguments)
      options = {}
      parser = option_parser(options)
      parser.parse!(arguments)
      puts parser if options[:help]
      return if options[:help]

      raise OptionParser::InvalidArgument, parser.to_s unless arguments.empty? && options[:path]

      options.fetch(:path)
    end

    def self.option_parser(options)
      OptionParser.new do |flags|
        flags.banner = 'Usage: shaka checkpoint --content-file PATH'
        flags.on('--content-file PATH', 'Checkpoint content as JSON') { |value| options[:path] = value }
        flags.on('-h', '--help', 'Show usage') { options[:help] = true }
      end
    end

    def self.content(path)
      parsed = JSON.parse(File.read(path, encoding: 'UTF-8'))
      raise Error, 'Checkpoint content must be an object.' unless parsed.is_a?(Hash)

      parsed
    end

    private_class_method :content_path, :option_parser, :content

    def initialize(content)
      @content = content
    end

    def result
      return { 'status' => 'proceed' } if proceed?

      reason = pause_reason
      { 'status' => 'pause', 'reason' => reason, 'action' => action(reason) }
    end

    private

    def proceed?
      value_established? && explicit_settings? && matching_settings? && active_settings? &&
        immediate_start? && settings_available?
    end

    # Absent means the user named the task, which already establishes its value.
    # Only an agent proposing work, or acting on an unverified report, sets this false.
    # A present non-boolean is a malformed verdict, not a quiet yes.
    def value_established?
      verdict = @content.fetch('value_established', true)
      [true, false].include?(verdict) ? verdict : raise(Error, 'Checkpoint value_established must be true or false.')
    end

    def explicit_settings?
      %w[requested_model requested_effort recommended_model recommended_effort].all? do |field|
        @content[field].is_a?(String) && !@content[field].strip.empty?
      end
    end

    def matching_settings?
      @content['requested_model'] == @content['recommended_model'] &&
        @content['requested_effort'] == @content['recommended_effort']
    end

    def active_settings?
      active_settings_reported? && @content['active_model'] == @content['recommended_model'] &&
        @content['active_effort'] == @content['recommended_effort']
    end

    def immediate_start? = @content['immediate_start'] == true

    def settings_available? = @content['settings_available'] == true

    def pause_reason
      return 'value_not_established' unless value_established?

      settings_pause_reason
    end

    def settings_pause_reason
      return 'settings_unavailable' unless settings_available?
      return 'settings_not_explicit' unless explicit_settings?
      return 'settings_conflict' if settings_conflict?
      return 'settings_unverified' unless active_settings_reported?
      return 'settings_inactive' unless active_settings?
      return 'immediate_start_not_authorized' unless immediate_start?

      'settings_not_explicit'
    end

    def settings_conflict? = recommendation_present? && !matching_settings?

    def active_settings_reported?
      %w[active_model active_effort].all? do |field|
        @content[field].is_a?(String) && !@content[field].strip.empty?
      end
    end

    def action(reason)
      return VALUE_ACTION if reason == 'value_not_established'

      return 'Select an available model and effort, then reply ready.' if reason == 'settings_unavailable'

      return 'Resolve the requested and recommended settings, then reply ready.' if reason == 'settings_conflict'

      return 'Confirm the active model and effort, then reply ready.' if reason == 'settings_unverified'

      if reason == 'settings_inactive'
        return format('Set the host to %<model>s with %<effort>s effort, then reply ready.',
                      model: @content['recommended_model'], effort: @content['recommended_effort'])
      end

      return 'Reply ready to begin implementation.' if reason == 'immediate_start_not_authorized'

      'Confirm a model and effort, then reply ready.'
    end

    def recommendation_present?
      %w[recommended_model recommended_effort].all? do |field|
        @content[field].is_a?(String) && !@content[field].strip.empty?
      end
    end
  end
end
