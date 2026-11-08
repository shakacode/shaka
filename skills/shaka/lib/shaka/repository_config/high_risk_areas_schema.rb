# frozen_string_literal: true

require_relative 'validation'
require_relative '../defaults'

module Shaka
  class RepositoryConfig
    # Named groups of paths where a change is always high risk, whatever a reviewer rates it, or at least
    # medium under MediumRiskAreasSchema. A repository's list for an area replaces the packaged one; an empty
    # list turns the area off.
    class HighRiskAreasSchema
      include Validation

      KEY = 'high_risk_areas'
      NAME = /\A[a-z][a-z0-9_]{0,39}\z/

      def self.effective(settings) = Defaults.fetch(self::KEY).merge(settings || {})

      def initialize(areas) = @areas = areas

      def validate
        key = self.class::KEY
        mapping!(@areas, key)
        @areas.each do |name, globs|
          raise Error, "#{key} names must be lowercase words, not #{name.inspect}" unless name.to_s.match?(NAME)
          next if globs.is_a?(Array) && globs.all? { |glob| glob.is_a?(String) && !glob.strip.empty? }

          raise Error, "#{key}.#{name} must be a list of path patterns"
        end
      end
    end

    # Paths where a change counts as at least medium risk, so Auto at low hands it to a person for a skim.
    class MediumRiskAreasSchema < HighRiskAreasSchema
      KEY = 'medium_risk_areas'
    end
  end
end
