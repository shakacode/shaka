# frozen_string_literal: true

require 'shellwords'
require_relative 'official'
require_relative 'status_states'

module Shaka
  module Install
    # Host folders whose Shaka links reach different installs (C5). Two registered checkouts that claim
    # different hosts unify under the one whose record changed last, through its installer's --take-over.
    # The step names that checkout; a person who wants the other runs the other's --take-over instead.
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
        return [nil, DECIDE] if StatusStates.credentials?(winner.record['repository'])

        [take_over(winner), nil]
      rescue SystemCallError
        [nil, DECIDE]
      end

      # A take-over follows the other checkout's origin and branch unless told otherwise, and the winner's
      # installer refuses a source it was not registered with.
      def take_over(winner)
        words = [File.join(winner.root, 'bin/install'), '--take-over', '--repository', winner.record['repository'],
                 '--branch', winner.record['branch']]
        words.map { |word| Shellwords.escape(word) }.join(' ')
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
