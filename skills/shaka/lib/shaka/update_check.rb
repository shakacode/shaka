# frozen_string_literal: true

require 'json'
require 'shellwords'
require 'tmpdir'
require_relative 'doctor/installation_identity'
require_relative 'update_check/launch'
require_relative 'update_check/messages'

module Shaka
  # Advisory comparison with the registered origin branch; never changes an installation.
  class UpdateCheck
    include Messages

    ROOT = File.expand_path('../../../..', __dir__)
    GUIDE = 'https://github.com/shakacode/shaka/blob/main/skills/shaka/references/official-installation.md'
    GITHUB = %r{\A(?:https://github\.com/|git@github\.com:|ssh://(?:git@)?github\.com/)
                ([A-Za-z0-9-]+/[A-Za-z0-9._-]+?)(?:\.git)?/?\z}xi
    BRANCH = %r{\A(?!-)[A-Za-z0-9._/-]+\z}
    COMMIT = /\A[0-9a-f]{40}\z/

    def self.run(arguments)
      return usage(arguments) unless arguments.empty?

      puts JSON.generate(installed.result)
      0
    rescue Shaka::Error, JSON::ParserError, KeyError, SystemCallError => e
      warn "Shaka update check unavailable: #{e.class}. See #{GUIDE} and retry."
      0
    end

    def self.usage(arguments)
      puts 'Usage: shaka update-check (read-only, advisory; 15-second network deadline)'
      arguments == ['--help'] ? 0 : 1
    end

    def self.installed
      identity = Doctor::InstallationIdentity.read
      record_path = File.join(ROOT, '.git/shaka-install.json')
      record = JSON.parse(File.read(record_path)) if File.file?(record_path)
      raise Shaka::Error, 'Invalid installation record' if record && !record.is_a?(Hash)

      new(source: identity.fetch('source'), branch: record&.fetch('branch', nil) || 'main',
          helper: File.join(ROOT, 'skills/shaka/scripts/shaka'), checkout: (ROOT if record))
    end

    private_class_method :installed, :usage

    # Only a registered installation has a checkout, and its comparison starts from the files on
    # disk rather than the revision its record names.
    def initialize(source:, branch:, helper:, checkout: nil, runner: Launch.method(:capture))
      @source = source
      @branch = branch
      @helper = helper
      @checkout = checkout
      @runner = runner
    end

    def result
      return answer('uninstalled', 'Use the official installer to receive update guidance.') if
        @source['kind'] == 'uninstalled'
      return development unless @source['kind'] == 'revision'

      repository = @source['repository'].to_s[GITHUB, 1]
      return unsupported_source unless repository && supported_revision?

      compare(repository)
    rescue Launch::Unavailable => e
      unknown(e.reason, e.message)
    rescue Shaka::Error, JSON::ParserError, SystemCallError, TypeError
      unknown('invalid_response', 'GitHub returned an answer this check cannot read.')
    end

    private

    def recorded = @source['revision'].to_s
    def supported_revision? = @branch.to_s.match?(BRANCH) && recorded.match?(COMMIT)

    def compare(repository)
      official = repository.casecmp?('shakacode/shaka') && @branch == 'main'
      @target = official ? 'official main' : "#{repository} #{@branch}"
      head = checkout_head
      endpoint = "repos/#{repository}/compare/#{head}...#{@branch}"
      output, error, ok = @runner.call(['gh', 'api', '--hostname', 'github.com', endpoint, '--jq',
                                        '{status: .status, ahead_by: .ahead_by}'], Dir.tmpdir)
      return request_failed(error) unless ok

      response = JSON.parse(output)
      raise TypeError unless response.is_a?(Hash)

      comparison(response['status'], response['ahead_by'], head)
    end

    def checkout_head
      return recorded unless @checkout

      output, error, ok = @runner.call(['git', '-C', @checkout, 'rev-parse', '--verify', 'HEAD'], @checkout)
      head = output.strip
      return head if ok && head.match?(COMMIT)

      raise Launch::Unavailable.new('checkout_unreadable', "Could not read #{@checkout}: #{first_line(error)}")
    end

    def comparison(status, ahead_by, head)
      case status
      when 'identical' then head == recorded ? current : drift(head)
      when 'ahead' then available(ahead_by)
      when 'behind', 'diverged' then @checkout ? local_commits : custom
      else raise TypeError
      end
    end
  end
end
