# frozen_string_literal: true

require 'open3'
require_relative '../error'
require_relative '../publication/text'
require_relative 'destination'
require_relative 'owner_tag'

module Shaka
  class BranchHead
    # What a release tells the next owner: the live head, its checks, the remaining work, and what is unpushed.
    class ReleaseReport
      PASSED = %w[SUCCESS NEUTRAL SKIPPED].freeze
      PENDING = ['', 'PENDING', 'EXPECTED', 'QUEUED', 'IN_PROGRESS'].freeze

      def initialize(root, pull, content)
        @root = root
        @pull = pull
        @content = content
      end

      def rows(maintainer, tag)
        { 'Head' => "`#{@pull['head']}`", 'Checks' => checks, 'Remaining work' => text('remaining'),
          'Unpushed work' => maintainer ? reported_unpushed : "in the releasing checkout: #{unpushed}",
          'Released by' => "#{maintainer ? 'maintainer' : 'owner'} `#{tag}`" }
      end

      private

      def checks
        counts = Array(@pull['checks']).map { |check| result(check) }.tally
        return 'none reported' if counts.empty?

        %w[passed failed pending].filter_map { |kind| "#{counts[kind]} #{kind}" if counts[kind] }.join(', ')
      end

      def result(check)
        value = (check['conclusion'].to_s.empty? ? check['state'] : check['conclusion']).to_s.upcase
        return 'pending' if PENDING.include?(value)

        PASSED.include?(value) ? 'passed' : 'failed'
      end

      # A maintainer releasing for an absent owner cannot see that owner's checkout, so says what it was told.
      def reported_unpushed
        return text('unpushed') if @content['unpushed']

        "UNKNOWN: a maintainer released the PR without inspecting the owner's checkout"
      end

      # Commits the PR head lacks, changed files, and stash entries, read from the owner's checkout.
      def unpushed
        branch = OwnerTag.branch(@root)
        if branch != @pull['branch']
          return "UNKNOWN: this checkout holds #{branch}, not the PR branch #{@pull['branch']}"
        end

        ahead = commits_ahead(branch)
        return "UNKNOWN: this clone lacks the PR head #{@pull['head']}; fetch it and release again" unless ahead

        summary = counts(ahead).filter_map { |label, count| "#{label}: #{count}" if count.positive? }
        summary.empty? ? 'none' : summary.join(', ')
      rescue Error => e
        "UNKNOWN: #{e.message}"
      end

      def commits_ahead(branch)
        Integer(git('rev-list', '--count', "#{@pull['head']}..refs/heads/#{branch}"))
      rescue Error
        nil
      end

      def counts(ahead)
        { 'unpushed commits' => ahead, 'changed files' => git('status', '--porcelain').lines.size,
          'stash entries in this clone' => git('stash', 'list').lines.size }
      end

      def git(*arguments)
        output, error, status = Open3.capture3(Destination::ENVIRONMENT, 'git', '-C', @root, *arguments)
        raise Error, "git #{arguments.first} failed: #{error.strip}" unless status.success?

        output
      end

      def text(field) = PublicationText.single_line(@content[field], field)
    end
  end
end
