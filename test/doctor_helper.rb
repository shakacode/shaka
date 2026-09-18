# frozen_string_literal: true

require 'shaka/doctor'

# Builds a Doctor whose every outside dependency is supplied, so each test states exactly
# the machine it describes.
module DoctorHelper
  INSTALLED = "gh version 2.64.0 (2026-09-01)\n"
  WRITABLE = '{"nameWithOwner":"owner/repo","viewerPermission":"WRITE"}'

  DEFAULTS = { root: nil, environment: { 'SHAKA_MACHINE_ALIAS' => 'm5' }, responses: {}, runner: nil,
               usage_files: nil, host_name: 'test-machine.local' }.freeze

  def doctor(**overrides)
    options = DEFAULTS.merge(overrides)
    system = Shaka::Doctor::System.new(runner: options[:runner] || stub_gh(options[:responses]),
                                       usage_source: ->(_host) { options[:usage_files] || [__FILE__] },
                                       host_name: options[:host_name])
    subject = Shaka::Doctor.new(root: options[:root] || File.expand_path('..', __dir__),
                                environment: options[:environment], system: system)
    [subject.report, subject.blocked?]
  end

  def check_names(report) = report.scan(/^\[\w+\] ([^\n]+?) —/).flatten.sort

  def stub_gh(responses)
    lambda do |argv|
      key = argv.include?('--version') ? :version : :view
      responses.fetch(key, key == :version ? [INSTALLED, '', true] : [WRITABLE, '', true])
    end
  end
end
