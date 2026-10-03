# frozen_string_literal: true

require_relative 'handoff_helper'

class HandoffWipNoteTest < Minitest::Test
  def test_the_revision_reads_back_from_a_rendered_description
    body = HandoffFixtures.description

    assert_equal "feature @ #{HandoffFixtures::HEAD}", Shaka::Handoff::WipNote.revision(body)
  end

  def test_notes_published_under_current_and_previous_headings_still_read
    ['Chat name', 'Task'].product(['Chat link', 'Thread']).each do |name, link|
      body = HandoffFixtures.description.sub('| Chat name |', "| #{name} |")
                            .sub('| Chat link |', "| #{link} |")

      assert_equal "feature @ #{HandoffFixtures::HEAD}", Shaka::Handoff::WipNote.revision(body),
                   "#{name} / #{link}"
    end
  end

  def test_a_body_saved_with_crlf_line_endings_still_reads
    body = HandoffFixtures.description.gsub("\n", "\r\n")

    assert_equal "feature @ #{HandoffFixtures::HEAD}", Shaka::Handoff::WipNote.revision(body)
  end

  def test_an_incomplete_table_has_no_revision
    body = HandoffFixtures.description.sub(/^\| Owner \|.*\n/, '')

    assert_nil Shaka::Handoff::WipNote.revision(body)
  end

  def test_a_body_without_the_note_has_no_revision
    assert_nil Shaka::Handoff::WipNote.revision('plain body')
  end
end
