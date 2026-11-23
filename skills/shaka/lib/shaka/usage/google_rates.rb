# frozen_string_literal: true

module Shaka
  # Google rates in the rate card. The section is optional, so a card from a checkout cut
  # before it existed still loads and prices no Google model.
  module GoogleRates
    def google_verified = @data.dig('google', 'verified')
    def google_model?(name) = google_models.key?(name.to_s)

    # A configured ID can end in its effort, such as `gemini-4-argon-high`; Google prices the model.
    def google_name(configured, effort)
      return unless configured.is_a?(String)

      bare = configured.delete_suffix("-#{effort}") if effort.is_a?(String)
      [configured, bare].compact.find { |name| google_model?(name) }
    end

    # The price in force on a response's UTC date. A model whose price changes needs that date.
    def google_prices(model, day)
      entry = google_models.fetch(model.to_s)
      changes = entry.fetch('from', {})
      return entry['prices'] if changes.empty?
      return unless day

      started = changes.select { |start, _| start <= day }
      started.empty? ? entry['prices'] : started.max_by(&:first).last
    end

    private

    def google_models = @data.fetch('google', {}).fetch('models', {})

    # Checks for the section, using the rate-card schema's shared helpers.
    module Schema
      private

      def google
        section = mapping(@data.fetch('google'), 'google', %w[verified models])
        { 'verified' => date(section.fetch('verified'), 'google verified'),
          'models' => models(section.fetch('models'), 'google') { |entry, label| google_model(entry, label) } }
      end

      def google_model(entry, label)
        fields = mapping(entry, label, %w[prices from])
        priced = { 'prices' => prices(fields.fetch('prices'), 3, "#{label} prices") }
        priced['from'] = price_changes(fields.fetch('from'), label) if fields.key?('from')
        priced
      end

      # A price under `from` applies from that date, so each date must be one.
      def price_changes(value, label)
        mapping(value, "#{label} from").to_h do |day, change|
          [date(day, "#{label} from date"), prices(change, 3, "#{label} prices from #{day}")]
        end
      end
    end
  end
end
