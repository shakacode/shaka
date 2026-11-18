# frozen_string_literal: true

require 'yaml'
require_relative '../error'

module Shaka
  module Companions
    # One repository pack file: the repository's own skills and each skill's mode at each skill point.
    #
    #   version: 1
    #   pack: team
    #   skills:
    #     release-checklist:
    #       path: DIR   # a project skill directory in this repository
    #       explicit_only: false   # also fans_out and setup; each defaults to false
    #       points:
    #         delivery#when-a-task-needs-several-prs: { mode: suggest, reason: one line }
    #         '*': { mode: decline, reason: one line }   # every point not named; decline only
    class Pack
      MODES = %w[decline suggest use].freeze
      FLAGS = %w[explicit_only fans_out setup].freeze
      ANY = '*'
      NAME = /\A[a-z0-9][a-z0-9_-]*\z/
      KEYS = %w[version pack skills].freeze
      SKILL_KEYS = (FLAGS + %w[path points]).freeze
      POINT_KEYS = %w[mode reason].freeze
      UNSAFE_PARTS = ['', '.', '..'].freeze
      BOOLEANS = [true, false].freeze

      Skill = Data.define(:name, :flags, :path, :points)

      attr_reader :name, :skills, :label

      # Parses one pack file's text; `label` names the file in errors.
      def self.parse(text, label:)
        new(YAML.safe_load(text, aliases: false), label:)
      rescue Psych::Exception => e
        raise Error, "#{label} is not valid YAML: #{e.message.lines.first.strip}"
      end

      def initialize(data, label:)
        @label = label
        top!(data)
        @name = data.fetch('pack')
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
      end

      def name?(value) = value.is_a?(String) && value.match?(NAME)

      def skills!(value)
        check!(value.is_a?(Hash), 'skills must be a mapping')
        value.map { |name, entry| skill!(name, entry, "skills.#{name}") }
      end

      def skill!(name, entry, label)
        check!(name?(name), "#{label} must be a skill name")
        check!(entry.is_a?(Hash), "#{label} must be a mapping")
        unknown!(entry, SKILL_KEYS, "#{label} has ")
        Skill.new(name:, flags: flags!(entry, label), path: path!(entry['path'], label),
                  points: points!(entry.fetch('points', {}), label))
      end

      # Only a flag the file states is recorded.
      def flags!(entry, label)
        FLAGS.select { |flag| entry.key?(flag) }.to_h do |flag|
          check!(BOOLEANS.include?(entry[flag]), "#{label}.#{flag} must be true or false")
          [flag, entry[flag]]
        end
      end

      def path!(path, label)
        parts = path.is_a?(String) ? path.split('/') : []
        valid = !parts.empty? && !path.start_with?('/') && !parts.intersect?(UNSAFE_PARTS)
        check!(valid, "#{label}.path must name a relative directory inside the repository")
        path
      end

      def points!(value, label)
        check!(value.is_a?(Hash), "#{label}.points must be a mapping")
        value.to_h { |point, setting| [point, point!(point, setting, "#{label}.points.#{point}")] }
      end

      def point!(point, setting, where)
        check!(setting.is_a?(Hash) && setting.keys.length == 2 && (setting.keys - POINT_KEYS).empty?,
               "#{where} must set mode and reason")
        mode, reason = setting.values_at('mode', 'reason')
        check!(MODES.include?(mode), "#{where}.mode must be one of #{MODES.join(', ')}")
        check!(point != ANY || mode == 'decline', "#{where} may only decline")
        check!(one_line?(reason), "#{where}.reason must be one line")
        [mode, reason]
      end

      def one_line?(text) = text.is_a?(String) && !text.strip.empty? && !text.include?("\n")
    end
  end
end
