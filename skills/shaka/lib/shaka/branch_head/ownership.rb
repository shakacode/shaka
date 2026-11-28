# frozen_string_literal: true

require 'json'
require_relative '../doctor/bounded_command'
require_relative '../error'

module Shaka
  class BranchHead
    # Who owns an unfinished PR, read from the release and pickup comments `handover release|pickup` post on it.
    # Each comment names the deciding comment it saw (`after`), and counts only if that is still the deciding one,
    # so of two writes made against the same state, the one GitHub stores first wins and the other changes nothing.
    # A release counts from the account holding the PR, a pickup only after a release, and a maintainer release or
    # override pickup only from an account with the maintain or admin role. Anyone can type the mark, so a comment
    # from an account without write access never counts.
    class Ownership
      MARK = /^<!-- shaka:ownership (\{.*\}) -->$/
      TAG = /\A[A-Za-z0-9][\w-]{0,39}\z/
      WRITERS = %w[admin write].freeze # GitHub reports maintain as write.
      MAINTAINERS = %w[admin maintain].freeze
      SECONDS = 30
      READS = 3

      GUIDANCE = {
        'released' => "The PR was released for pickup. Stop this chat's monitors, keep local work, and leave the " \
                      'branch and PR alone. Continue only after `handover pickup` makes this checkout the owner.',
        'taken_over' => "Another owner picked up this PR. Stop this chat's monitors, keep local work, leave the " \
                        'branch and PR alone, and report the local work to the user.'
      }.freeze

      def self.mark(event) = "<!-- shaka:ownership #{JSON.generate(event)} -->"

      # A released PR, or one another tag picked up, pauses this checkout; nil means it still holds the PR.
      def self.pause(state, tag)
        return 'released' if state['released']

        'taken_over' if state['owner'] && state['owner'] != tag
      end

      # request is the --pr match, with repository and number; author is the PR author, who holds it at first.
      # cli is [environment, path] for a GitHub CLI outside the checkout.
      def initialize(request, author, cli)
        @cli = cli
        @repository = request[:repository]
        @number = request[:number]
        @author = author
        @roles = {}
      end

      # { 'owner' => TAG or nil, 'released', 'id' and 'url' of the deciding comment, 'login' holding the PR,
      # 'applied' => ids of every comment that took effect }.
      # A nil owner that is not released means the original owner, who never picked the PR up, still holds it.
      def state(events = self.events)
        initial = { 'owner' => nil, 'released' => false, 'id' => 0, 'login' => @author, 'applied' => [] }
        events.each_with_object(initial) do |event, state|
          apply(state, event) if event['trusted'] && event['after'] == state['id'] && allowed?(event, state)
        end
      end

      # The state once GitHub lists comment id, read once more a moment later so a comment stored just before it
      # has time to appear too; nil when GitHub still does not list it after a few reads.
      def state_after(id)
        READS.times do |read|
          sleep(read) if read.positive?
          next unless events.any? { |event| event['id'] == id }

          sleep(1)
          return state
        end
        nil
      end

      def post(body) = write("repos/#{@repository}/issues/#{@number}/comments", 'POST', body)

      def edit(id, body) = write("repos/#{@repository}/issues/comments/#{id}", 'PATCH', body)

      private

      def apply(state, event)
        pickup = event['event'] == 'pickup'
        state.merge!('owner' => (event['owner'] if pickup), 'released' => !pickup, 'id' => event['id'],
                     'url' => event['url'], 'login' => (pickup ? event['login'] : state['login']),
                     'applied' => [*state['applied'], event['id']])
      end

      def allowed?(event, state)
        return role(event['login']).last.then { MAINTAINERS.include?(it) } if event['maintainer']
        return state['released'] if event['event'] == 'pickup'

        !state['released'] && event['login'] == state['login']
      end

      def events
        listing = gh('api', '--paginate', "repos/#{@repository}/issues/#{@number}/comments", '--jq',
                     '.[] | select(.body | contains("<!-- shaka:ownership ")) | ' \
                     '{id, url: .html_url, body, login: .user.login, type: .user.type}')
        listing.lines.filter_map { |line| event(JSON.parse(line)) }.sort_by { it['id'] }
      end

      def write(path, method, body) = JSON.parse(gh('api', path, '-X', method, '-f', "body=#{body}"))

      def event(comment)
        fields = JSON.parse(comment['body'].to_s[MARK, 1] || 'null')
        return unless fields.is_a?(Hash) && %w[release pickup].include?(fields['event'])

        fields.merge('id' => comment['id'], 'url' => comment['url'], 'login' => comment['login'],
                     'trusted' => writer?(comment))
      rescue JSON::ParserError
        nil
      end

      def writer?(comment) = comment['type'] == 'User' && WRITERS.include?(role(comment['login']).first)

      # [permission, role]; GitHub answers 404 for an account that is not a collaborator.
      def role(login)
        @roles[login] ||= gh('api', "repos/#{@repository}/collaborators/#{login}/permission",
                             '--jq', '"\(.permission) \(.role_name)"', missing: 'none none').split
      end

      def gh(*arguments, missing: nil)
        argv = [*@cli, *arguments]
        output, error, success = Doctor::BoundedCommand.new(timeout: SECONDS).call(argv)
        return output if success
        return missing if missing && error.include?('HTTP 404')

        raise Error, "Cannot read or write ownership on #{@repository}##{@number}: #{error.strip}"
      end
    end
  end
end
