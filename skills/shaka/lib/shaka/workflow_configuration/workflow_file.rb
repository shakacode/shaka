# frozen_string_literal: true

require 'yaml'
require_relative 'references'

module Shaka
  class WorkflowConfiguration
    # Reads caller-supplied secret names and environment names out of one workflow file.
    class WorkflowFile
      NAME = /\A[A-Za-z_][A-Za-z0-9_]*\z/
      BEFORE_ENVIRONMENT = %w[name if runs-on strategy concurrency environment].freeze

      def self.parse(text)
        new(text, YAML.safe_load(text.to_s, permitted_classes: [], aliases: false))
      rescue Psych::Exception
        new(text, nil)
      end

      def initialize(text, document)
        @text = text
        @document = document
      end

      def workflow? = @document.is_a?(Hash)
      def references = References.collect(@text)

      def scopes
        return [text_scope(@document.nil?)] unless workflow?

        [outside_scope, *job_scopes].compact
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

        jobs.values.flat_map { |job| job.is_a?(Hash) ? job_scope(job) : [] }
      end

      # GitHub reads the keys that decide whether and where a job runs before its environment applies,
      # so the environment cannot settle a name used there. It stays uncertain when the repository lacks it.
      def job_scope(job)
        environment = environment_name(job)
        return [names_scope(job, [], reusable?)].compact unless environment

        [names_scope(job.except(*BEFORE_ENVIRONMENT), [environment], reusable?),
         names_scope(job.slice(*BEFORE_ENVIRONMENT), [], true)].compact
      end

      def names_scope(value, environments, uncertain)
        found = References.collect(string_values(value).join("\n"))
        secrets = reject_caller(found['secrets'])
        scope(secrets, found['vars'], environments, uncertain) unless secrets.empty? && found['vars'].empty?
      end

      def outside_scope
        found = outside_names
        secrets = reject_caller(found['secrets'])
        return if secrets.empty? && found['vars'].empty?

        scope(secrets, found['vars'], [], reusable?)
      end

      def outside_names
        rest = @document.except('jobs')
        parsed = References.collect(string_values(rest).join("\n"))
        comments = comment_names
        { 'secrets' => (parsed['secrets'] + comments['secrets']).uniq,
          'vars' => (parsed['vars'] + comments['vars']).uniq }
      end

      def comment_names
        parsed = References.collect(string_values(@document).join("\n"))
        { 'secrets' => references['secrets'] - parsed['secrets'], 'vars' => references['vars'] - parsed['vars'] }
      end

      def reject_caller(names)
        return names unless reusable?

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

      def text_scope(uncertain)
        scope(references['secrets'], references['vars'], [], uncertain)
      end

      def scope(secrets, vars, environments, uncertain)
        Scope.new(secrets, vars, environments, uncertain)
      end

      # YAML reads a bare `on` key as true.
      def trigger = @document['on'] || @document[true]

      def triggers
        case trigger
        when Hash then trigger.keys
        else Array(trigger)
        end
      end

      # Only a caller starts this workflow, and it brings its own names, so this repository's lists
      # cannot settle them. Another trigger runs it here, where its names are checked like any other.
      def reusable? = triggers == ['workflow_call']

      def caller_secret_map
        return unless @document.is_a?(Hash)

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
