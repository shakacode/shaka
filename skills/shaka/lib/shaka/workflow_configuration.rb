# frozen_string_literal: true

require_relative 'error'
require_relative 'workflow_configuration/references'
require_relative 'workflow_configuration/workflow_file'
require_relative 'workflow_configuration/catalog'

module Shaka
  # Compares secret and variable names in workflow files a pull request changes
  # with the names visible to that repository. API values are discarded.
  class WorkflowConfiguration
    CLEAR = { 'status' => 'clear', 'missing' => [], 'unverified' => [] }.freeze
    UNVERIFIED = { 'status' => 'unverified', 'missing' => [], 'unverified' => [] }.freeze

    def self.references(text) = References.collect(text)

    def initialize(github)
      @catalog = Catalog.new(github)
    end

    def call(pull)
      sha = pull['headRefOid']
      raise Error, 'Expected a full commit SHA.' unless sha.is_a?(String) && sha.match?(/\A[0-9a-f]{40}\z/)

      state, paths = @catalog.workflow_paths
      return UNVERIFIED.dup unless state == :ok
      return CLEAR.dup if paths.empty?

      texts, unreadable = @catalog.read_workflows(paths, sha, head_repository(pull))
      missing, pending = compare(texts)
      report(missing, pending + unreadable)
    end

    private

    def compare(texts)
      scopes = texts.flat_map { |text| WorkflowFile.read(text).scopes }
      return [[], []] if scopes.empty?

      divide(scopes, @catalog.repository_access)
    end

    def divide(scopes, access)
      missing = []
      pending = []
      scopes.each { |item| append_scope(item, access, missing, pending) }
      [missing.uniq, (pending.uniq - missing)]
    end

    def append_scope(item, access, missing, pending)
      [['secrets', item.secrets], ['vars', item.vars]].each do |kind, names|
        found, held = @catalog.classify(kind, names, access, environments: item.environments,
                                                             uncertain: item.uncertain ? names : [])
        missing.concat(found)
        pending.concat(held)
      end
    end

    def report(missing, pending)
      status = if missing.any?
                 'missing'
               else
                 (pending.any? ? 'unverified' : 'clear')
               end
      { 'status' => status, 'missing' => missing, 'unverified' => pending }
    end

    def head_repository(pull)
      name = pull.dig('headRepository', 'nameWithOwner')
      name.is_a?(String) && name.match?(Catalog::HEAD_REPOSITORY) ? name : @catalog.repository
    end
  end
end
