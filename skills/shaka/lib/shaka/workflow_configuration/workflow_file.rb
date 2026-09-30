# frozen_string_literal: true

require 'yaml'
require_relative 'references'

module Shaka
  class WorkflowConfiguration
    # Reads caller-supplied secret names and environment names out of one workflow file.
    class WorkflowFile
      NAME = /\A[A-Za-z_][A-Za-z0-9_]*\z/

      def self.read(text)
        new(text, YAML.safe_load(text.to_s, permitted_classes: [], aliases: false))
      rescue Psych::Exception
        new(text, nil)
      end

      def initialize(text, document)
        @text = text
        @document = document
      end

      def parsed? = !@document.nil?
      def references = References.collect(@text)

      def caller_secrets
        secrets = caller_secret_map
        return [] unless secrets

        secrets.keys.select { |key| key.is_a?(String) && key.match?(NAME) }
      end

      def environments
        jobs = @document['jobs'] if @document.is_a?(Hash)
        return [] unless jobs.is_a?(Hash)

        jobs.values.filter_map { |job| environment_name(job) }.uniq
      end

      private

      def caller_secret_map
        return unless @document.is_a?(Hash)

        trigger = @document['on'] || @document[true]
        call = trigger['workflow_call'] if trigger.is_a?(Hash)
        secrets = call['secrets'] if call.is_a?(Hash)
        secrets if secrets.is_a?(Hash)
      end

      def environment_name(job)
        return unless job.is_a?(Hash)

        case job['environment']
        when String then job['environment']
        when Hash then job['environment']['name'] if job['environment']['name'].is_a?(String)
        end
      end
    end
  end
end
