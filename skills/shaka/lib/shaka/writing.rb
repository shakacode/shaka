# frozen_string_literal: true

require_relative 'writing/advisory'
require_relative 'writing/duplication'

module Shaka
  # Checks the part of the writing baseline a machine can check. Cross-document
  # duplication is a spec violation, so it refuses; everything else only prints.
  # A summary that passes both can still be fluent and wrong: only an adversarial
  # reader with repository access establishes that it is true.
  module Writing
    module_function

    def advise(text, label)
      warn "shaka: #{label} writing advisory, not enforced"
      Advisory.new(text).lines.each { |line| warn "shaka:   #{line}" }
    end
  end
end
