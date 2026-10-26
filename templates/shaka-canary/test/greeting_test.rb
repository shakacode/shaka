# frozen_string_literal: true

require_relative '../lib/greeting'

raise "expected hello, got #{Greeting.hello.inspect}" unless Greeting.hello == 'hello'
