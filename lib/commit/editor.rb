# frozen_string_literal: true

require_relative "commit_editor"
require_relative "scm"
require_relative "settings"

module Commit
  # Everything that happens to the text while it is being edited: the
  # over-long-title highlight, the read-only comment block, the blank line
  # git wants after the summary, auto-capitalization, and Ctrl+/ commenting.
  class Editor
    def initialize(overlay:, save_button:, parsed:)
      @overlay = overlay
      @save_button = save_button
      @parsed = parsed
      @capitalizer = Capitalizer.new
      @previous_line_count = 1
    end

    attr_reader :overlay, :save_button, :parsed

    def build
      commit_editor.tap do |editor|
        overlay.child = editor.build
        editor.show_right_margin = message?

        buffer.tap do |b|
          b.tag_table.add(title_too_long_tag)
          b.signal_connect("changed") { update_highlight }
        end

        view.tap do |v|
          v.add_controller(comment_controller)
          # connect_after, or GtkTextView's own handler would overwrite the
          # narrowed selection right back to everything.
          v.signal_connect_after("select-all") { |_view, selected| limit_select_all(selected) }
        end

        comment_controller.signal_connect("key-pressed") do |_controller, keyval, _keycode, state|
          on_key_pressed(keyval, state)
        end

        update
        fill_buffer

        if message?
          buffer.signal_connect("end-user-action") { on_end_user_action }
        end
      end
    end

    # Re-reads the config — the preferences dialog calls this when it closes.
    def update
      Settings.load
      commit_editor.wrap_width_request = config.body_length_wrap
      update_highlight
    end

    def config = Settings.local

    def commit_editor = @commit_editor ||= CommitEditor.new(language: parsed[:language])

    def view = commit_editor.view
    def buffer = commit_editor.buffer

    def wider_than_wrap_width_request? = commit_editor.wider_than_wrap_width_request?

    def message? = parsed[:is_message]
    def comment_prefix = parsed[:comment_prefix]

    # The buffer starts out holding the body, a blank line and the comment
    # block. Not undoable — this is the file's own content, not an edit.
    def fill_buffer
      buffer.text = "#{parsed[:body]}\n#{parsed[:comment]}"
      buffer.place_cursor(buffer.get_iter_at(offset: parsed[:cursor_position]))

      if parsed[:read_only_index] > -1
        mark_comment_read_only
      end
    end

    # git will strip the comment block anyway, so editing it is pointless and
    # confusing. The mark is also where select-all stops.
    def mark_comment_read_only
      buffer.get_iter_at(offset: parsed[:read_only_index] - 1).then do |comment_iter|
        buffer.tag_table.add(read_only_tag)
        buffer.apply_tag(read_only_tag, comment_iter, buffer.end_iter)
        buffer.create_mark("comment", comment_iter, false)
      end
    end

    # Save stays insensitive until there is something other than comments to
    # commit; past the title length hint the overflow goes red.
    def update_highlight
      save_button.sensitive = !Scm.empty_commit_message?(buffer.text, comment_prefix)

      if message?
        highlight_title_overflow
      end
    end

    def highlight_title_overflow
      lines_of(buffer.text).first.length.then do |first_line_length|
        # Clear the whole buffer, not just the first line: highlighted text
        # can be copied and pasted further down.
        buffer.remove_tag(title_too_long_tag, buffer.start_iter, buffer.end_iter)

        if first_line_length > config.title_length_hint
          buffer.apply_tag(
            title_too_long_tag,
            buffer.get_iter_at(offset: config.title_length_hint),
            buffer.get_iter_at(offset: first_line_length),
          )
        end
      end
    end

    def limit_select_all(selected)
      if selected
        buffer.get_mark("comment").then do |mark|
          if mark
            buffer.select_range(buffer.start_iter, buffer.get_iter_at(mark: mark))
          end
        end
      end

      false
    end

    def on_key_pressed(keyval, state)
      if comment_prefix && keyval == Gdk::Keyval::KEY_slash && control?(state)
        toggle_line_comment
        true
      else
        false
      end
    end

    def control?(state) = !(state.to_i & Gdk::ModifierType::CONTROL_MASK.to_i).zero?

    # Keeps the summary line and the body separated by exactly one blank
    # line, the way git wants them — pressing Return at the end of the
    # summary jumps straight past the blank line.
    def on_end_user_action
      buffer.cursor_position.then do |cursor|
        if config.auto_capitalize_title
          @capitalizer.call(buffer, cursor)
        end
      end

      lines = lines_of(buffer.text)
      line_count = lines.length + 1
      first_line_length = lines.first.length

      if swallow_newline?(lines, first_line_length, line_count)
        buffer.backspace(buffer.get_iter_at(offset: buffer.cursor_position), true, true)

        lines = lines_of(buffer.text)
        first_line_length = lines.first.length
        line_count = lines.length + 1
      end

      if needs_blank_line?(first_line_length, line_count)
        buffer.insert_interactive_at_cursor_raw("\n", 1, true)
      end

      @previous_line_count = line_count
    end

    # A Return pressed on an empty summary line would leave two empty lines
    # behind; drop the one just typed.
    def swallow_newline?(lines, first_line_length, line_count)
      buffer.cursor_position == first_line_length + 1 &&
        lines[0].to_s.delete(" ").empty? &&
        lines[1].to_s.delete(" ").empty? &&
        line_count > @previous_line_count
    end

    def needs_blank_line?(first_line_length, line_count)
      buffer.cursor_position == first_line_length + 1 &&
        line_count == comment_line_count + 3 &&
        line_count > @previous_line_count
    end

    def comment_line_count = lines_of(parsed[:comment]).length

    # Ruby's "".split gives [], where the JS this was ported from gives [""].
    def lines_of(text)
      text.split("\n", -1).then do |lines|
        if lines.empty?
          [""]
        else
          lines
        end
      end
    end

    # Ctrl+/ — comments or uncomments the selected lines, or the line the
    # cursor is on. Lines inside the read-only comment block are skipped.
    def toggle_line_comment
      line_range.then do |(start_line, end_line)|
        lines_of(buffer.get_text(buffer.start_iter, buffer.end_iter, false)).then do |lines|
        all_commented = all_commented?(lines, start_line, end_line)

        buffer.begin_user_action
        (start_line..end_line).each do |line_number|
          apply_comment_toggle(lines, line_number, all_commented)
        end
        buffer.end_user_action
      end
      end
    end

    def line_range
      buffer.selection_bounds.then do |bounds|
        if bounds
          selection_line_range(bounds)
        else
          buffer.get_iter_at(offset: buffer.cursor_position).line.then { |line| [line, line] }
        end
      end
    end

    # A selection that ends at the very start of a line does not include that
    # line as far as the user is concerned.
    def selection_line_range(bounds)
      [bounds.first.line, bounds.last.line].then do |(start_line, end_line)|
        if bounds.last.line_offset.zero? && end_line > start_line
          [start_line, end_line - 1]
        else
          [start_line, end_line]
        end
      end
    end

    def all_commented?(lines, start_line, end_line)
      (start_line..end_line).none? do |line_number|
        lines[line_number].to_s.lstrip.then do |trimmed|
          line_number < lines.length && !trimmed.empty? && !trimmed.start_with?(comment_prefix)
        end
      end
    end

    def apply_comment_toggle(lines, line_number, all_commented)
      if line_number < lines.length && !lines[line_number].strip.empty?
        if all_commented && lines[line_number].lstrip.start_with?(comment_prefix)
          uncomment_line(lines, line_number)
        elsif !all_commented
          comment_line(lines, line_number)
        end
      end
    end

    def uncomment_line(lines, line_number)
      lines[line_number].then do |line_text|
        indent = line_text.length - line_text.lstrip.length
        start_offset = line_start_offset(lines, line_number) + indent
        text = buffer.get_text(buffer.start_iter, buffer.end_iter, false)
        # Eat the space after the marker too, so a round trip is lossless.
        space = space_after_prefix(text, start_offset)
        end_offset = start_offset + comment_prefix.length + space

        buffer.get_iter_at(offset: start_offset).then do |from|
          buffer.get_iter_at(offset: end_offset).then do |to|
            if from.editable(true) && to.editable(true)
              buffer.delete(from, to)
              lines[line_number] = line_text[0, indent] + line_text[(indent + comment_prefix.length + space)..].to_s
            end
          end
        end
      end
    end

    def space_after_prefix(text, start_offset)
      (start_offset + comment_prefix.length).then do |after|
        if after < text.length && text[after] == " "
          1
        else
          0
        end
      end
    end

    def comment_line(lines, line_number)
      lines[line_number].then do |line_text|
        (line_text =~ /\S/).then do |indent|
          if indent
            buffer.get_iter_at(offset: line_start_offset(lines, line_number) + indent).then do |at|
              if at.editable(true)
                buffer.insert(at, "#{comment_prefix} ")
                lines[line_number] = "#{line_text[0, indent]}#{comment_prefix} #{line_text[indent..]}"
              end
            end
          end
        end
      end
    end

    # `lines` is kept in step with the buffer as we edit, so the offsets of
    # the lines below the one being changed stay right.
    def line_start_offset(lines, line_number)
      lines[0, line_number].sum { |line| line.length + 1 }
    end

    def title_too_long_tag
      @title_too_long_tag ||= Gtk::TextTag.new.tap do |tag|
        tag.foreground = "#e01b24"
      end
    end

    def read_only_tag
      @read_only_tag ||= Gtk::TextTag.new("readonly").tap do |tag|
        tag.editable = false
      end
    end

    def comment_controller = @comment_controller ||= Gtk::EventControllerKey.new

    # Capitalizes the first letter of the summary, once. "fix: something"
    # capitalizes after the colon rather than the prefix.
    class Capitalizer
      def initialize
        @complete = false
      end

      def call(buffer, cursor_position)
        if !@complete && cursor_position >= 3
          capitalize(buffer, cursor_position)
        end
      end

        private

          def capitalize(buffer, cursor_position)
            buffer.text[(cursor_position - 3), 2].to_s.then do |last_chars|
              if last_chars[1] == " " && first_word?(buffer, cursor_position)
                # Only ever once, so backspacing out of it does not have the
                # app immediately do it again.
                @complete = true
                apply(buffer, cursor_position, last_chars)
              end
            end
          end

          def first_word?(buffer, cursor_position)
            buffer.get_iter_at(offset: cursor_position - 3).backward_search(" ", 0, nil).nil?
          end

          def apply(buffer, cursor_position, last_chars)
            if last_chars[0] == ":"
              buffer.change_case(
                GtkSource::ChangeCaseType::UPPER,
                buffer.get_iter_at(offset: cursor_position - 1),
                buffer.get_iter_at(offset: cursor_position),
              )
            else
              buffer.change_case(
                GtkSource::ChangeCaseType::UPPER,
                buffer.start_iter,
                buffer.get_iter_at(offset: 1),
              )
            end
          end
    end
  end
end
