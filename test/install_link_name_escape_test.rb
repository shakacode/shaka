# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/install/status_checkout'

# A cleanup decision names each link by its file name, which can hold any bytes, so the name is shown escaped
# and never raises, whatever encoding Ruby read it in.
class InstallLinkNameEscapeTest < Minitest::Test
  SEPARATOR = [0x2028].pack('U')
  ACCENT = [0xE9].pack('U')

  def test_names_in_every_encoding_are_escaped_without_raising
    {
      "dev\nNext" => 'dev\x0ANext',
      "sep#{SEPARATOR}Next" => 'sep\u2028Next',
      'back\slash' => 'back\\\\slash',
      "caf#{ACCENT}" => "caf#{ACCENT}",
      "bad\xFF".dup.force_encoding(Encoding::UTF_8) => 'bad\xFF',
      "caf#{ACCENT}".b => 'caf\xC3\xA9',
      "caf#{ACCENT}".encode(Encoding::ISO_8859_1) => 'caf\xE9'
    }.each { |name, shown| assert_equal shown, shown_name(name), name.inspect }
  end

  private

  def shown_name(name)
    checkout = Shaka::Install::StatusCheckout.new('/missing', { 'targets' => [] })
    name.chars.map { |character| checkout.send(:escaped, character) }.join
  end
end
