# frozen_string_literal: true

require 'yaml'
require_relative '../error'

module Shaka
  module Companions
    # Value checks the pack schema shares.
    module PackValues
      private

      def name?(value) = value.is_a?(String) && value.match?(Pack::NAME)

      def strings?(value) = value.is_a?(Hash) && value.all? { |key, text| key.is_a?(String) && text.is_a?(String) }

      def string_list?(list) = list.is_a?(Array) && list.all? { |item| item.is_a?(String) && !item.empty? }

      def one_line?(text) = text.is_a?(String) && !text.strip.empty? && !text.include?("\n")

      def relative?(path)
        parts = path.is_a?(String) ? path.split('/') : []
        !parts.empty? && !path.start_with?('/') && !parts.intersect?(Pack::UNSAFE_PARTS)
      end
    end

    # One pack file: a skill pack's source, how to recognize its installed copy, and for each
    # skill the mode at each skill point. `layer` is packaged, repository, or personal.
    #
    #   version: 1
    #   pack: shakaperf
    #   source: https://github.com/shakacode/shakaperf
    #   match: { plugins: [shakaperf], paths: ['**/shakaperf/**'] }
    #   install: { claude: '...' }
    #   skills:
    #     shaka-perf-coverage:
    #       explicit_only: false   # also fans_out and setup; each defaults to false
    #       study: URL             # required for a packaged `use`
    #       path: DIR              # repository packs only: a project skill in this repository
    #       points:
    #         ui-verification#ui-changes: { mode: suggest, reason: one line }
    #         '*': { mode: decline, reason: one line }   # every point; decline only
    class Pack
      include PackValues

      LAYERS = %w[packaged repository personal].freeze
      MODES = %w[decline suggest use].freeze
      FLAGS = %w[explicit_only fans_out setup].freeze
      ANY = '*'
      NAME = /\A[a-z0-9][a-z0-9_-]*\z/
      KEYS = %w[version pack source match install skills].freeze
      SKILL_KEYS = (FLAGS + %w[study path points]).freeze
      MATCH_KEYS = %w[plugins paths].freeze
      UNSAFE_PARTS = ['', '.', '..'].freeze
      BOOLEANS = [true, false].freeze

      Skill = Data.define(:name, :flags, :study, :path, :points)

      attr_reader :layer, :name, :source, :match, :install, :skills, :label

      # Parses one pack file's text; `label` names the file in errors.
      def self.parse(text, layer:, label:)
        data = YAML.safe_load(text, aliases: false)
        new(data, layer:, label:)
      rescue Psych::Exception => e
        raise Error, "#{label} is not valid YAML: #{e.message.lines.first.strip}"
      end

      def initialize(data, layer:, label:)
        raise ArgumentError, "unknown layer #{layer}" unless LAYERS.include?(layer)

        @layer = layer
        @label = label
        top!(data)
        @name = data.fetch('pack')
        @source = data['source']
        @match = match!(data.fetch('match', {}))
        @install = data.fetch('install', {})
        @skills = skills!(data.fetch('skills', {}))
      end

      private

      def check!(valid, message) = valid || raise(Error, "#{@label}: #{message}")

      def unknown!(hash, allowed, where)
        unknown = hash.keys - allowed
        check!(unknown.empty?, "#{where}unknown key #{unknown.first}")
      end

      def top!(data)
        check!(data.is_a?(Hash), 'must be a mapping')
        check!(data['version'] == 1, 'must set version: 1')
        unknown!(data, KEYS, '')
        check!(name?(data['pack']), 'pack must be a lowercase name')
        check!(data['source'].nil? || data['source'].is_a?(String), 'source must be a string')
        check!(strings?(data.fetch('install', {})), 'install must map coding agents to commands')
      end

      def match!(value)
        check!(value.is_a?(Hash), 'match must be a mapping')
        unknown!(value, MATCH_KEYS, 'match has ')
        value.each { |key, list| check!(string_list?(list), "match.#{key} must be a list of strings") }
        MATCH_KEYS.to_h { |key| [key, value.fetch(key, [])] }
      end

      def skills!(value)
        check!(value.is_a?(Hash), 'skills must be a mapping')
        value.map { |name, entry| skill!(name, entry, "skills.#{name}") }
      end

      def skill!(name, entry, label)
        check!(name?(name), "#{label} must be a skill name")
        check!(entry.is_a?(Hash), "#{label} must be a mapping")
        unknown!(entry, SKILL_KEYS, "#{label} has ")
        path = path!(entry['path'], label)
        identity!(label, path)
        points = points!(entry.fetch('points', {}), label)
        study!(entry['study'], points, label)
        Skill.new(name:, flags: flags!(entry, label), study: entry['study'], path:, points:)
      end

      # Only a flag the file states is recorded, so a repository entry clears a flag only by saying false.
      def flags!(entry, label)
        FLAGS.select { |flag| entry.key?(flag) }.to_h do |flag|
          check!(BOOLEANS.include?(entry[flag]), "#{label}.#{flag} must be true or false")
          [flag, entry[flag]]
        end
      end

      def path!(path, label)
        return if path.nil?

        check!(@layer == 'repository', "#{label}.path is allowed only in a repository pack")
        check!(relative?(path), "#{label}.path must be a relative directory inside the repository")
        path
      end

      # A third-party skill is recognized by its source and the pack's match rules.
      def identity!(label, path)
        return if path

        check!(@source, "#{label} needs the pack's source")
        check!(@match.values.any?(&:any?), "#{label} needs match.plugins or match.paths")
      end

      def points!(value, label)
        check!(value.is_a?(Hash), "#{label}.points must be a mapping")
        value.to_h { |point, setting| [point, point!(point, setting, "#{label}.points.#{point}")] }
      end

      def point!(point, setting, where)
        check!(setting.is_a?(Hash) && setting.keys.sort == %w[mode reason], "#{where} must set mode and reason")
        mode, reason = setting.values_at('mode', 'reason')
        check!(MODES.include?(mode), "#{where}.mode must be one of #{MODES.join(', ')}")
        check!(point != ANY || mode == 'decline', "#{where} may only decline")
        check!(one_line?(reason), "#{where}.reason must be one line")
        [mode, reason]
      end

      # ShakaCode ships a `use` entry to everyone only with the study that supports it.
      def study!(study, points, label)
        check!(study.nil? || study.to_s.start_with?('https://'), "#{label}.study must be a URL")
        packaged_use = @layer == 'packaged' && points.values.any? { |mode, _| mode == 'use' }
        check!(!packaged_use || study, "#{label} is a packaged use entry without a study")
      end
    end
  end
end
