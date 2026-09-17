# frozen_string_literal: true

require_relative 'test_helper'
require 'rbconfig'

class TrustedConfigSourceTest < Minitest::Test
  def test_file_can_report_its_own_errors_when_required_directly
    library = File.expand_path('../skills/shaka/lib', __dir__)
    script = <<~RUBY
      require 'shaka/trusted_config_source'
      Shaka::TrustedConfigSource.new(root: Dir.pwd).read('missing-ref')
    RUBY

    output, status = Open3.capture2e(RbConfig.ruby, '-I', library, '-e', script)

    refute status.success?
    assert_includes output, 'Shaka::Error'
    refute_includes output, 'uninitialized constant'
  end
end
