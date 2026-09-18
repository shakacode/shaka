# frozen_string_literal: true

require 'shaka/doctor'

# Builds a Doctor whose every outside dependency is supplied, so each test states exactly
# the machine it describes.
module DoctorHelper
  INSTALLED = "gh version 2.64.0 (2026-09-01)\n"
  WRITABLE = '{"nameWithOwner":"owner/repo","viewerPermission":"WRITE"}'

  def doctor(root: File.expand_path('..', __dir__), environment: { 'SHAKA_MACHINE_ALIAS' => 'm5' },
             responses: {}, runner: nil, usage_files: [__FILE__])
    subject = Shaka::Doctor.new(root: root, environment: environment, runner: runner || stub_gh(responses),
                                usage_source: ->(_host) { usage_files })
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
