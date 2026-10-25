# frozen_string_literal: true

require_relative 'decision_replay'

module Shaka
  module Evaluation
    # Public known-failure regression cases; expected actions stay in the trusted controller.
    module ReleaseSafetyBank
      FIXTURE = File.expand_path('../../../fixtures/release-safety.json', __dir__)
      SOURCES = [__FILE__, FIXTURE, MergeAuthorization::FIXTURE, *DecisionReplay::SOURCES].freeze

      module_function

      def cases = MergeAuthorization.cases + JSON.parse(File.read(FIXTURE)).fetch('cases')

      def version
        hashes = SOURCES.map { Digest::SHA256.file(it).hexdigest }
        "sha256:#{Digest::SHA256.hexdigest(JSON.generate(hashes))}"
      end

      def prompt(id, workflow)
        return MergeAuthorization.prompt(id, workflow) if MergeAuthorization.cases.any? { it.fetch('id') == id }

        fixture = JSON.parse(File.read(FIXTURE))
        scenario = fixture.fetch('cases').find { it.fetch('id') == id }
        raise ArgumentError, 'Unknown release safety case' unless scenario

        [MergeAuthorization::INSTRUCTIONS, fixture.fetch('context'),
         "User initiating message: #{scenario.fetch('user')}", scenario.fetch('state'),
         "Follow the supplied skill to select the next actions.\n\nSkill workflow:\n#{workflow}"].join("\n\n")
      end
    end
  end
end
