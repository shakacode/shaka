# frozen_string_literal: true

require 'shellwords'
require_relative 'official'
require_relative 'status_states'

module Shaka
  module Install
    # Host folders whose Shaka links reach different installs (C5). Two registered checkouts that claim
    # different hosts unify under the one with the newer record, through its installer's --take-over.
    class StatusSplit
      DECIDE = 'Choose one install, then rerun its bin/install with every --agent you use.'

      def initialize(inventory)
        @inventory = inventory
      end

      def finding
        owners = links.to_h { |entry| [entry['path'], @inventory.owner(entry) || entry['target']] }
        return if owners.values.uniq.size < 2

        detail = owners.map { |path, owner| "#{path} -> #{owner}" }.join('; ')
        command, decision = step(owners)
        StatusStates.finding('C5', @inventory.home, detail, command:, decision:)
      end

      private

      def links = @inventory.links.select { |entry| entry['name'] == 'shaka' }

      # A take-over moves the links of exactly one other checkout, and only in the host folders.
      def step(owners)
        checkouts = owners.values.uniq.map { |root| @inventory.checkouts[root] }
        return [nil, DECIDE] unless checkouts.all? && checkouts.size == 2 && owners.keys.all? { |path| host?(path) }

        unify(*checkouts)
      end

      def unify(first, second)
        shared = claimed(first) & claimed(second)
        return [nil, both_claim([first, second], shared)] if shared.any?

        winner = [first, second].max_by { |checkout| File.mtime(record(checkout)) }
        ["#{Shellwords.escape(File.join(winner.root, 'bin/install'))} --take-over", nil]
      rescue SystemCallError
        [nil, DECIDE]
      end

      def both_claim(checkouts, shared)
        "Both #{checkouts.map(&:root).join(' and ')} record #{shared.join(', ')}; choose one install, then " \
          'rerun its bin/install with every --agent you use.'
      end

      def claimed(checkout) = checkout.record['targets'].map { |target| File.expand_path(target['directory']) }
      def record(checkout) = File.join(checkout.root, '.git', Checkout::RECORD)
      def host?(path) = @inventory.host_directories.include?(File.dirname(path))
    end
  end
end
