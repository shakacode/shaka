# frozen_string_literal: true

require_relative '../configuration'
require_relative '../configuration/fingerprint'
require_relative '../doctor/installation_identity'
require_relative 'public_settings'

module Shaka
  module Evidence
    # Resolve the same private or trusted configuration used by an operation.
    class Inputs
      def self.capture(root:, ref:, repository:, task_overrides: {})
        config, selected, kind = resolve_source(root, ref)
        installation = Doctor::InstallationIdentity.read
        fingerprint = Configuration::Fingerprint.build(
          root:, effective_settings: config.to_h.merge('task_overrides' => task_overrides), repository:,
          installation:, **selected
        )
        snapshot = public_snapshot(root:, config:, kind:, ref:, task_overrides:, installation:)
        [config, fingerprint.to_h, kind, snapshot]
      end

      def self.public_snapshot(root:, ref:, **settings)
        snapshot = PublicSettings.capture(ref:, **settings)
        return snapshot unless settings[:kind] == 'preview/local'

        policy = TrustedConfigSource.from_ref(root:, ref:, private_trial: true)
        PublicSettings.with_policy(snapshot, policy)
      end
      private_class_method :public_snapshot

      def self.resolve_source(root, ref)
        Configuration.resolve_source(root:, ref:)
      end
    end
  end
end
