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

      def scopes
        return [scope(references['secrets'], references['vars'], [], true)] unless parsed?

        jobs = job_scopes
        [outside_scope(jobs), *jobs].compact
      end

      def caller_secrets
        secrets = caller_secret_map
        return [] unless secrets

        secrets.keys.select { |key| key.is_a?(String) && key.match?(NAME) }
      end

      private

      def job_scopes
        jobs = @document['jobs'] if @document.is_a?(Hash)
        return [] unless jobs.is_a?(Hash)

        jobs.values.filter_map { |job| job_scope(job) }
      end

      def job_scope(job)
        return unless job.is_a?(Hash)

        found = References.collect(string_values(job).join("\n"))
        secrets = reject_caller(found['secrets'])
        return if secrets.empty? && found['vars'].empty?

        environment = environment_name(job)
        scope(secrets, found['vars'], environment ? [environment] : [], false)
      end

      def outside_scope(jobs)
        used = jobs.flat_map { |item| item.secrets + item.vars }
        secrets = reject_caller(references['secrets'] - used)
        vars = references['vars'] - used
        return if secrets.empty? && vars.empty?

        scope(secrets, vars, [], false)
      end

      def reject_caller(names)
        names.reject { |name| caller_secrets.any? { |declared| declared.casecmp?(name) } }
      end

      def string_values(value)
        case value
        when String then [value]
        when Hash then value.each_value.flat_map { |item| string_values(item) }
        when Array then value.flat_map { |item| string_values(item) }
        else []
        end
      end

      def scope(secrets, vars, environments, uncertain)
        Scope.new(secrets, vars, environments, uncertain)
      end

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

    # One set of names checked against one set of environments.
    class Scope
      attr_reader :secrets, :vars, :environments, :uncertain

      def initialize(secrets, vars, environments, uncertain)
        @secrets = secrets
        @vars = vars
        @environments = environments
        @uncertain = uncertain
      end
    end
  end
end
