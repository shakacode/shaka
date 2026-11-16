# frozen_string_literal: true

require_relative 'publication_test'

class PublicationSectionOrderTest < Minitest::Test
  def test_template_sections_follow_metrics_and_optional_wip_before_the_credit
    [nil, PublicationWipDetailsTest::WIP].each do |wip|
      content = PublicationRegressionTest.new(name).description_content(
        'wip' => wip, 'sections' => [{ 'heading' => 'Changelog', 'body' => 'Notes.' }]
      )
      settings = Shaka::PublicationSettings.new(current: { 'pr_description.show_shaka_credit' => true })
      rendered = Shaka::Publication.description(content, nil, nil, settings)
      headings(wip).each_cons(2) do |before, after|
        assert_operator rendered.index(before), :<, rendered.index(after), "#{before} should precede #{after}"
      end
    end
  end

  def headings(wip)
    result = ['## Verification', '<summary>Evidence and limitations', '## Shaka metrics']
    result << '<summary>WIP Details' if wip
    result.push('## Changelog', '_PR prepared with')
  end
end
