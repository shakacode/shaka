# frozen_string_literal: true

module Shaka
  # Finds the checkout boundary without invoking a candidate-controlled Git executable.
  module OpeningCheckout
    module_function

    def root(dir)
      directory = File.realpath(dir)
      directory = File.dirname(directory) until File.exist?(File.join(directory, '.git')) ||
                                                directory == File.dirname(directory)
      File.exist?(File.join(directory, '.git')) ? directory : nil
    rescue SystemCallError
      nil
    end
  end
end
