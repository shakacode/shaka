# frozen_string_literal: true

require_relative 'test_helper'

# Human guides in docs/ must not send readers into agent instructions; see AGENTS.md.
class DocsAgentLinksTest < Minitest::Test
  DOCS = File.expand_path('../docs', __dir__)
  AGENT_REFERENCES = %r{(?:\A|/)skills/shaka/references(?:/|\z)}

  def agent_reference_links(text)
    inline = text.scan(/\]\(\s*<?([^)\s>]+)/).flatten
    defined = text.scan(/^\s{0,3}\[[^\]]+\]:\s*<?(\S+?)>?(?:\s|$)/).flatten
    html = text.scan(/href=["']([^"']+)["']/).flatten
    (inline + defined + html).grep(AGENT_REFERENCES)
  end

  def test_finds_relative_and_github_links_to_agent_references
    text = <<~MARKDOWN
      Read [the review guide](../skills/shaka/references/review.md#choose).
      See [upstream](https://github.com/shakacode/shaka/blob/main/skills/shaka/references/delivery.md).
      [guide]: <skills/shaka/references/local-review.md>
      <a href="https://github.com/shakacode/shaka/tree/main/skills/shaka/references">all</a>
    MARKDOWN

    assert_equal 4, agent_reference_links(text).size
  end

  def test_allows_configuration_files_and_human_guides
    text = <<~MARKDOWN
      Copy [the defaults](../skills/shaka/config/defaults.yml) and read [settings](settings.md).
      The agent keeps its procedures in its own references folder.
    MARKDOWN

    assert_empty agent_reference_links(text)
  end

  def test_human_docs_do_not_link_to_agent_references
    offenders = Dir.glob(File.join(DOCS, '**', '*.md')).flat_map do |path|
      agent_reference_links(File.read(path)).map { |link| "#{path.delete_prefix("#{DOCS}/")}: #{link}" }
    end

    assert_empty offenders, 'Link to a human guide in docs/ instead of skills/shaka/references/'
  end
end
