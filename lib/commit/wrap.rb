# frozen_string_literal: true

module Commit
  # Re-wraps the body of a commit message at a maximum line length.
  #
  # Comment lines are left exactly as they are — git strips them later, and
  # rewrapping them would corrupt the diff `git commit -v` puts in there.
  module Wrap
    module_function

    def call(text, width, comment_prefix)
      text.split("\n", -1).map do |line|
        if line.start_with?(comment_prefix) || line.length <= width
          line
        else
          wrap_line(line, width, comment_prefix)
        end
      end.join("\n")
    end

    def wrap_line(line, width, comment_prefix)
      pieces = []
      rest = line

      while rest.length > width
        wrap_at = find_wrap_position(width, rest, comment_prefix)
        if wrap_at.zero?
          break
        end

        pieces << rest[0, wrap_at]
        # Since we only wrap at a whitespace, it's safe to "+1" to drop it
        # from the start of the next line.
        rest = rest[(wrap_at + 1)..]
      end

      pieces.push(rest).join("\n")
    end

    # Walks back from the wrap column to the last space, refusing one that
    # would push a comment marker to the start of the next line.
    def find_wrap_position(width, line, comment_prefix)
      width.downto(1).find do |i|
        line[i] == " " && line[i + 1] != comment_prefix
      end || 0
    end
  end
end
