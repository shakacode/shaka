# frozen_string_literal: true

module Shaka
  module Evaluation
    # The protected controller declares check names and their expected GitHub App IDs.
    module DeliveryChecks
      private

      def read_checks(api)
        @checks.values.uniq.flat_map do |app|
          path = "repos/#{@repository}/commits/#{@head}/check-runs?per_page=100&filter=latest&app_id=#{app}"
          result = JSON.parse(api.get(path))
          observed = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          rows = result.fetch('check_runs')
          unavailable unless rows.is_a?(Array) && rows.size <= 100 && result.fetch('total_count') == rows.size
          selected_checks(rows, app, observed)
        end
      end

      def selected_checks(rows, app, observed)
        selected = rows.select { |row| @checks[row.fetch('name')] == app }
        unavailable unless selected.map { it.fetch('name') }.uniq.size == selected.size
        selected.map { normalize_check(it, app, observed) }
      end

      def normalize_check(row, app, observed)
        unavailable unless check_identity?(row, app) && row.fetch('status').is_a?(String) &&
                           [String, NilClass].any? { row['conclusion'].is_a?(it) }

        { 'id' => row.fetch('id'), 'suite_id' => row.fetch('check_suite').fetch('id'),
          'app_id' => app, 'head' => @head, 'name' => row.fetch('name'),
          'status' => row.fetch('status'), 'conclusion' => row.fetch('conclusion'), 'observed_at' => observed }
      end

      def check_identity?(row, app)
        [row.fetch('id'), row.fetch('check_suite').fetch('id')].all? { it.is_a?(Integer) && it.positive? } &&
          row.dig('app', 'id') == app && row.fetch('head_sha') == @head
      end
    end
  end
end
