# frozen_string_literal: true

module Shaka
  # One part of a reviewer prompt and where its text came from. A runner sends the joined texts;
  # `shaka prompt show` prints the same sections with their sources, so the two cannot differ.
  PromptSection = Data.define(:source, :text) do
    def self.join(sections) = sections.map(&:text).join
  end
end
