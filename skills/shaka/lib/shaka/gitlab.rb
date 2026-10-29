# frozen_string_literal: true

require 'json'
require 'open3'
require 'uri'
require_relative 'error'
require_relative 'gitlab/transport'

module Shaka
  # GitLab-native project and API reads; no GitHub review or merge semantics.
  class GitLab
    include Transport

    def initialize(host:, project:, runner: nil)
      @host = validated_host(host)
      @project = validated_project(project)
      @runner = runner || ->(argv, stdin_data:) { Open3.capture3(*argv, stdin_data:) }
    end

    def project
      result = api("projects/#{URI.encode_www_form_component(@project)}")
      unless matching_project?(result) && readable_project?(result)
        raise Error, 'GitLab project identity or default branch did not match the requested project.'
      end

      result
    end

    def default_revision
      first = project
      branch = default_branch(first)
      last = project
      unless first.values_at('id', 'default_branch') == last.values_at('id', 'default_branch') &&
             branch.dig('commit', 'id') == default_branch(last).dig('commit', 'id')
        raise Error, 'GitLab project or default revision changed during the read.'
      end

      first.slice('id', 'path_with_namespace', 'web_url', 'visibility', 'default_branch', 'permissions')
           .merge('provider' => 'gitlab', 'host' => @host, 'sha' => branch.dig('commit', 'id'))
    end

    private

    def matching_project?(info)
      info['id'].is_a?(Integer) && info['id'].positive? && info['path_with_namespace'] == @project &&
        info['web_url'] == "https://#{@host}/#{@project}"
    end

    def readable_project?(info)
      %w[public internal private].include?(info['visibility']) &&
        info['default_branch'].is_a?(String) && !info['default_branch'].strip.empty?
    end

    def default_branch(info)
      name = info.fetch('default_branch')
      branch = api("projects/#{info.fetch('id')}/repository/branches/#{URI.encode_www_form_component(name)}")
      commit = branch['commit']
      unless branch['name'] == name && branch['default'] == true && commit.is_a?(Hash) &&
             commit['id'].is_a?(String) && commit['id'].match?(/\A[0-9a-f]{40}\z/)
        raise Error, 'GitLab default branch did not return its named commit.'
      end

      branch
    end

    def validated_host(host)
      if host.is_a?(String) && host.ascii_only?
        match = /\A([A-Za-z0-9]+(?:[.-][A-Za-z0-9]+)*)(?::([1-9]\d{0,4}))?\z/.match(host)
      end
      raise Error, 'Expected a GitLab hostname with an optional port.' unless match &&
                                                                              (!match[2] || match[2].to_i <= 65_535)

      host.downcase.freeze
    end

    def validated_project(project)
      valid = project.is_a?(String) && project.ascii_only? &&
              project.match?(%r{\A[A-Za-z0-9._~-]+(?:/[A-Za-z0-9._~-]+)+\z}) &&
              !project.split('/').intersect?(%w[. ..])
      raise Error, 'Expected a full GitLab project namespace.' unless valid

      project.dup.freeze
    end
  end
end
