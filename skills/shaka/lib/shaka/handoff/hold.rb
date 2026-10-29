# frozen_string_literal: true

require_relative '../attention'
require_relative '../merge_hold'

module Shaka
  # Reports a maintainer's hold label beside the attention label. The maintainer owns the hold,
  # so nothing is owed for it.
  module HandoffHold
    # The trusted MergeHold; unset applies the shipped hold labels.
    attr_writer :hold

    private

    # Reads the PR's labels once for both the attention label and the hold.
    def read_labels
      attention = Attention.new(@github)
      @names = attention.all
      @labels = attention.current(@names)
    end

    def hold_fact
      label = (@hold || MergeHold.new).label(@names)
      note("held by #{label}", "#{label} holds this PR; `merge` refuses it until a person removes the label.") if label
    end
  end
end
