# frozen_string_literal: true

require 'uri'
require_relative '../error'
require_relative '../git_origin'
require_relative 'destination'
require_relative 'owner_tag'

module Shaka
  class BranchHead
    # Whether a checkout can work on the PR it is about to pick up: its branch is the PR's head branch, the local
    # branch and origin's both sit at the PR head, and origin pushes to the PR's head repository, not a mirror.
    module PickupCheckout
      module_function

      def verify(root, head, pull)
        branch = OwnerTag.branch(root)
        check = head.check
        return if branch == pull['branch'] && [check['live'], check['local']].all?(pull['head']) &&
                  pushes_to?(root, pull)

        raise Error, "Cannot pick up from this checkout: #{branch} is at #{check['local']} and origin/#{branch} at " \
                     "#{check['live'] || 'nothing'}, but the PR head is #{pull['repository']} #{pull['branch']} at " \
                     "#{pull['head']}."
      end

      def pushes_to?(root, pull)
        url = Destination.new(root:, branch: pull['branch']).url
        GitOrigin.identity(url).delete_suffix('.git').casecmp?(pull['repository'].to_s) &&
          URI(GitOrigin.canonical_url(url)).host.to_s.casecmp?(pull['host'].to_s)
      rescue Error
        false
      end
    end
  end
end
