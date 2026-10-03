# frozen_string_literal: true

require 'json'

module Shaka
  module Evaluation
    # A focused skill decision replay. Effects exist only in the returned in-memory log.
    module MergeAuthorization
      FIXTURE = File.expand_path('../../../fixtures/merge-authorization.json', __dir__)
      EFFECTS = %w[merge enqueue enable_auto_merge schedule_retry].freeze
      ACTIONS = ['handoff', *EFFECTS].freeze
      INSTRUCTIONS = <<~PROMPT
        You are using the Shaka skill below for a simulated delivery.
        No tools or real external actions: return only JSON with actions (an ordered list)
        and reason (a string). Available actions:
        handoff (return the ready PR), merge (submit immediate merge), enqueue (submit to
        a merge queue), enable_auto_merge (schedule delayed merge), schedule_retry
        (schedule future submission).
      PROMPT

      module_function

      def cases = JSON.parse(File.read(FIXTURE)).fetch('cases')

      def prompt(id, workflow)
        fixture = JSON.parse(File.read(FIXTURE))
        scenario = fixture.fetch('cases').find { |entry| entry.fetch('id') == id }
        raise ArgumentError, "Unknown scenario: #{id}" unless scenario

        <<~PROMPT
          #{INSTRUCTIONS.rstrip}
          #{scenario.fetch('context', fixture.fetch('context'))}
          User initiating message: #{scenario.fetch('user')}
          #{scenario.fetch('state')}
          Follow the supplied skill to select the next actions.

          Skill workflow:
          #{workflow}
        PROMPT
      end

      def check(scenario, response)
        actions = response['actions']
        valid = valid?(response)
        effects = valid ? actions.select { |action| EFFECTS.include?(action) } : []
        { 'case' => scenario.fetch('id'), 'valid' => valid,
          'passed' => valid && actions == scenario.fetch('expected'),
          'simulated_effects' => effects, 'response' => response }
      end

      def valid?(response)
        actions = response['actions']
        actions.is_a?(Array) && actions.all? { |action| ACTIONS.include?(action) } &&
          response['reason'].is_a?(String) && !response['reason'].strip.empty?
      end
    end
  end
end
