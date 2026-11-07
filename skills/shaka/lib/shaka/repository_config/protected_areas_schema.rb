# frozen_string_literal: true

require_relative 'validation'
require_relative '../defaults'

module Shaka
  class RepositoryConfig
    # Named groups of paths where a change is always high risk, whatever a reviewer rates it.
    # A repository's list for an area replaces the packaged one; an empty list turns the area off.
    class ProtectedAreasSchema
      include Validation

      KEY = 'protected_areas'
      NAME = /\A[a-z][a-z0-9_]{0,39}\z/

      def self.effective(settings) = Defaults.fetch(KEY).merge(settings || {})

      def initialize(areas) = @areas = areas

      def validate
        mapping!(@areas, KEY)
        @areas.each do |name, globs|
          raise Error, "#{KEY} names must be lowercase words, not #{name.inspect}" unless name.to_s.match?(NAME)
          next if globs.is_a?(Array) && globs.all? { |glob| glob.is_a?(String) && !glob.strip.empty? }

          raise Error, "#{KEY}.#{name} must be a list of path patterns"
        end
      end
    end
  end
end
