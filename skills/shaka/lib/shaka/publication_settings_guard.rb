# frozen_string_literal: true

require_relative 'error'
require_relative 'publication_settings'

module Shaka
  # Catches a previewed renderer that redefines what publication_settings.rb defines, such as an
  # unrebased head's settings.rb. Head renderers run in this process, so this is not a boundary
  # against deliberate head code; only same-repository heads, whose diff is inspected first, preview.
  module PublicationSettingsGuard
    # A real path, so a symlinked load path still matches the locations Ruby reports.
    FILE = File.realpath(File.expand_path('publication_settings.rb', __dir__))

    module_function

    def snapshot
      klass = PublicationSettings
      keys = klass.singleton_methods(false).map { [:singleton, it] } + klass.constants(false).map { [:constant, it] } +
             (klass.instance_methods(false) + klass.private_instance_methods(false)).map { [:instance, it] }
      found = values(keys).select { |(kind, name), value| defined_here?(kind, name, value) }
      # An empty snapshot would pass every head, so fail closed when the file was not recognized.
      raise Error, 'Rendering preview cannot locate the installed settings verification.' unless
        found.key?(%i[singleton verify])

      found
    end

    # A removed method or constant counts as a change.
    def changed?(snapshot)
      values(snapshot.keys) != snapshot
    rescue NameError
      true
    end

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
      path = location&.first
      path && File.exist?(path) && File.realpath(path) == FILE
    end

    private_class_method :values, :defined_here?
  end
end
