# frozen_string_literal: true

require_relative 'publication_settings'

module Shaka
  # Detects a rendering preview redefining what publication_settings.rb defines: evidence reading,
  # verification, and publication policy. It lives outside publication/, so a preview never loads it.
  module PublicationSettingsGuard
    FILE = File.expand_path('publication_settings.rb', __dir__)

    module_function

    def snapshot
      klass = PublicationSettings
      keys = klass.singleton_methods(false).map { [:singleton, it] } + klass.constants(false).map { [:constant, it] } +
             (klass.instance_methods(false) + klass.private_instance_methods(false)).map { [:instance, it] }
      values(keys).select { |(kind, name), value| defined_here?(kind, name, value) }
    end

    def changed?(snapshot) = values(snapshot.keys) != snapshot

    def values(keys)
      klass = PublicationSettings
      keys.to_h do |kind, name|
        value = case kind
                when :singleton then klass.method(name)
                when :instance then klass.instance_method(name)
                else klass.const_get(name)
                end
        [[kind, name], value]
      end
    end

    def defined_here?(kind, name, value)
      location = kind == :constant ? PublicationSettings.const_source_location(name) : value.source_location
      location&.first == FILE
    end

    private_class_method :values, :defined_here?
  end
end
