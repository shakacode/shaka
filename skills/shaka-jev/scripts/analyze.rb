# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative '../lib/shaka_jev/analysis'

options = {}
parser = OptionParser.new do |flags|
  flags.banner = 'Usage: analyze --pr-url URL --head SHA --evidence FILE'
  flags.on('--pr-url URL', 'Public GitHub PR URL') { |value| options[:pr_url] = value }
  flags.on('--head SHA', 'Exact commit being analyzed') { |value| options[:head] = value }
  flags.on('--evidence FILE', 'Reviewed public-safe evidence packet') { |value| options[:evidence] = value }
  flags.on('-h', '--help', 'Show usage') do
    puts flags
    exit
  end
end

begin
  parser.parse!
  unless ARGV.empty? && options.values_at(:pr_url, :head, :evidence).all?
    raise OptionParser::InvalidArgument, parser.to_s
  end

  evidence = File.binread(options.fetch(:evidence), ShakaJev::Analysis::MAX_EVIDENCE_BYTES + 1)
                 .force_encoding(Encoding::UTF_8)
  result = ShakaJev::Analysis.new(api_key: ENV.fetch('TYPESAFE_API_KEY', '')).call(
    pr_url: options.fetch(:pr_url), head: options.fetch(:head), evidence: evidence
  )
  puts JSON.pretty_generate(result)
rescue OptionParser::ParseError, ShakaJev::Error, SystemCallError, IOError => e
  warn "shaka-jev: #{e.message}"
  exit 1
end
