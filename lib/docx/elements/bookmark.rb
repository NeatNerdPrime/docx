require 'docx/elements/element'

module Docx
  module Elements
    class Bookmark
      include Element
      attr_accessor :name

      def self.tag
        'bookmarkStart'
      end

      def initialize(node)
        @node = node
        @name = @node['w:name']
      end

      # Insert text before bookmarkStart node
      def insert_text_before(text)
        text_run = get_run_before
        text_run.text = "#{text_run.text}#{text}"
      end

      # Insert text after bookmarkStart node
      def insert_text_after(text)
        text_run = get_run_after
        text_run.text = "#{text}#{text_run.text}"
      end

      # insert multiple lines starting with paragraph containing bookmark node.
      def insert_multiple_lines(text_array)
        # Hold paragraphs to be inserted into, corresponding to the index of the strings in the text array
        paragraphs = []
        paragraph = self.parent_paragraph
        # Remove text from paragraph
        paragraph.blank!
        paragraphs << paragraph
        for i in 0...(text_array.size - 1)
          # Copy previous paragraph
          new_p = paragraphs[i].copy
          # Insert as sibling of previous paragraph
          new_p.insert_after(paragraphs[i])
          paragraphs << new_p
        end

        # Insert text into corresponding newly created paragraphs
        paragraphs.each_index do |index|
          paragraphs[index].text = text_array[index]
        end
      end

      # Get text run immediately prior to bookmark node
      def get_run_before
        # at_xpath returns the first match found and preceding-sibling returns siblings in the
        # order they appear in the document not the order as they appear when moving out from
        # the starting node
        if not (r_nodes = @node.xpath("./preceding-sibling::w:r")).empty?
          r_node = r_nodes.last
          Containers::TextRun.new(r_node)
        elsif enclosing_paragraph
          new_r = Containers::TextRun.create_with(self)
          new_r.insert_before(self)
          new_r
        else
          # Block-level bookmark (e.g. Google Docs places bookmarkStart/End
          # directly under w:body). Append to the preceding paragraph, or start a
          # new paragraph before the bookmark, so the run lives inside a w:p.
          run_at_paragraph_end(@node.xpath("./preceding-sibling::w:p").last) ||
            run_in_new_paragraph { |paragraph| @node.add_previous_sibling(paragraph) }
        end
      end

      # Get text run immediately after bookmark node
      def get_run_after
        if (r_node = @node.at_xpath("./following-sibling::w:r"))
          Containers::TextRun.new(r_node)
        elsif enclosing_paragraph
          new_r = Containers::TextRun.create_with(self)
          new_r.insert_after(self)
          new_r
        else
          # Block-level bookmark: prepend to the following paragraph, or start a
          # new paragraph after the bookmark.
          run_at_paragraph_start(@node.at_xpath("./following-sibling::w:p")) ||
            run_in_new_paragraph { |paragraph| @node.add_next_sibling(paragraph) }
        end
      end

      # Override Element#parent_paragraph so insert_multiple_lines also works for
      # block-level bookmarks: fall back to the adjacent paragraph.
      def parent_paragraph
        node = enclosing_paragraph ||
               @node.at_xpath("./following-sibling::w:p") ||
               @node.xpath("./preceding-sibling::w:p").last
        Containers::Paragraph.new(node)
      end

      private

      # The w:p the bookmark sits inside, or nil when it is block-level.
      def enclosing_paragraph
        @node.at_xpath("./parent::w:p")
      end

      # A run at the start of paragraph_node (reusing its first run to keep
      # formatting, or creating one). nil when paragraph_node is nil.
      def run_at_paragraph_start(paragraph_node)
        return nil unless paragraph_node

        if (existing = paragraph_node.at_xpath("w:r"))
          return Containers::TextRun.new(existing)
        end

        new_r = Containers::TextRun.create_with(self)
        if (props = paragraph_node.at_xpath("w:pPr"))
          props.add_next_sibling(new_r.node)
        else
          paragraph_node.prepend_child(new_r.node)
        end
        new_r
      end

      # A run at the end of paragraph_node. nil when paragraph_node is nil.
      def run_at_paragraph_end(paragraph_node)
        return nil unless paragraph_node

        if (existing = paragraph_node.xpath("w:r").last)
          return Containers::TextRun.new(existing)
        end

        new_r = Containers::TextRun.create_with(self)
        paragraph_node.add_child(new_r.node)
        new_r
      end

      # Create a run wrapped in a fresh w:p; the block positions that paragraph
      # relative to the bookmark.
      def run_in_new_paragraph
        new_r = Containers::TextRun.create_with(self)
        paragraph = Nokogiri::XML::Node.new("w:p", @node.document)
        paragraph.add_child(new_r.node)
        yield paragraph
        new_r
      end
    end
  end
end