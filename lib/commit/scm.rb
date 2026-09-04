# frozen_string_literal: true

require_relative "wrap"

module Commit
  # Everything Commit knows about the files git and mercurial hand it: which
  # kind of message a path holds, how to split the message from the comment
  # block, and how to put it back together on save.
  module Scm
    module_function

    # The label on the confirm button, per kind of message.
    ACTIONS = {
      "commit" => "_Commit",
      "hg"     => "_Commit",
      "merge"  => "_Merge",
      "tag"    => "_Tag",
      "add -p" => "A_dd",
      "rebase" => "_Rebase",
    }.freeze

    # Kinds whose body is prose we may reflow and capitalize. A rebase todo
    # list or a hunk edit is not.
    MESSAGE_KINDS = [
      "hg",
      "commit",
      "git-merge-squash",
      "git-rebase-squash",
      "merge",
      "tag",
    ].freeze

    # Kinds where the cursor belongs at the top rather than after the body.
    CURSOR_AT_TOP_KINDS = ["rebase", "add -p", "git-merge-squash", "git-rebase-squash"].freeze

    def parse(text, type)
      if type == "config"
        parse_config(text)
      else
        parse_message(text, type)
      end
    end

    def parse_config(text)
      {
        body:            text,
        comment:         "",
        detail:          nil,
        comment_prefix:  "#",
        cursor_position: 0,
        read_only_index: -1,
        language:        "ini",
        action:          action_for("config"),
        is_message:      false,
        text:            text,
      }
    end

    def parse_message(text, type)
      comment_prefix = comment_prefix_for(type)
      kind = refine_kind(text, type)
      split = split_message(text, comment_prefix)
      comment_lines = split[:comment].split("\n")

      {
        body:            split[:body],
        comment:         split[:comment],
        detail:          detail_for(kind, split[:body], comment_lines),
        comment_prefix:  comment_prefix,
        cursor_position: cursor_position_for(kind, split[:body]),
        read_only_index: split[:read_only_index],
        language:        language_for(kind),
        action:          action_for(type),
        is_message:      MESSAGE_KINDS.include?(kind),
        text:            text,
      }
    end

    # The msgid only; the window translates it when it puts it on the button.
    def action_for(type) = ACTIONS[type] || "_Save"

    def comment_prefix_for(type)
      if type == "hg"
        "HG:"
      else
        "#"
      end
    end

    def language_for(kind)
      case kind
      when "hg" then "hg"
      when "add -p" then "diff"
      else "git"
      end
    end

    # Squashed merges and rebases arrive as ordinary commits but want the
    # cursor at the top, so they get a kind of their own.
    def refine_kind(text, type)
      case
      when type == "commit" && text.start_with?("Squashed commit of the following")
        "git-merge-squash"
      when type == "commit" && text.start_with?("# This is a combination of")
        "git-rebase-squash"
      else
        type
      end
    end

    def cursor_position_for(kind, body)
      if CURSOR_AT_TOP_KINDS.include?(kind)
        0
      else
        body.length
      end
    end

    # The bit shown after the filename in the title bar — branch, tag or the
    # two ends of a rebase.
    def detail_for(kind, body, comment_lines)
      case kind
      when "hg" then mercurial_branch(comment_lines)
      when "commit" then git_branch(comment_lines)
      when "merge" then merge_detail(body)
      when "tag" then git_tag(comment_lines)
      when "rebase" then rebase_detail(comment_lines)
      end
    end

    def merge_detail(body)
      merge_branch(body).then do |branch|
        if branch
          "branch #{branch}"
        end
      end
    end

    def rebase_detail(comment_lines)
      comment_lines[1].to_s.sub("# ", "").split(" ").then do |chunks|
        if chunks.length > 1
          "#{chunks[1]} → #{chunks[3]}"
        end
      end
    end

    def type_for(file)
      basename = File.basename(file)
      git_type(basename, file) || mercurial_type(basename, file)
    end

    def git_type(basename, path)
      case
      when basename == "COMMIT_EDITMSG" then "commit"
      when basename == "MERGE_MSG" then "merge"
      when basename == "TAG_EDITMSG" then "tag"
      when basename == "addp-hunk-edit.diff" then "add -p"
      when basename == "git-rebase-todo" then "rebase"
      when basename == ".gitconfig" then "config"
      when path.end_with?("/git/config") then "config"
      when path.end_with?("/.git/config") then "config"
      end
    end

    def mercurial_type(basename, path)
      case
      # https://www.man7.org/linux/man-pages/man5/hgrc.5.html#FILES
      when basename.end_with?(".commit.hg.txt") then "hg"
      when basename == ".hgrc" then "config"
      when path.end_with?("/.hg/hgrc") then "config"
      when path.end_with?("/.hg/hgrc-not-shared") then "config"
      when path.end_with?("/hg/hgrc") then "config"
      end
    end

    # These three read the branch/tag out of the comment block by position
    # rather than by wording, so they survive a localized git.
    def mercurial_branch(comment_lines)
      comment_lines[5].to_s.split(" ").last.to_s.split("'")[1]
    end

    def git_branch(comment_lines)
      comment_lines[4]&.split(" ")&.last
    end

    def git_tag(comment_lines)
      comment_lines[3]&.slice(1..)&.strip
    end

    def merge_branch(body) = body.split("'")[1]

    # The comment block starts at the first run of three comment lines — the
    # message itself may well contain a single one.
    def split_message(text, comment_prefix)
      prefix = Regexp.escape(comment_prefix)
      index = text =~ /^#{prefix}.*\n#{prefix}.*\n#{prefix}/

      if index.nil?
        { body: text, comment: "", read_only_index: -1 }
      else
        {
          body:            text[0, index].strip,
          comment:         "\n#{text[index..]}",
          read_only_index: index,
        }
      end
    end

    def empty_commit_message?(text, comment_prefix)
      text.split("\n").none? do |line|
        line.strip.then do |stripped|
          !stripped.empty? && !stripped.start_with?(comment_prefix)
        end
      end
    end

    # Reflows the body, leaving the title line alone.
    def format(text, length, comment_prefix)
      text.match(/\A([^\n]+)\n\n(.*)\z/m).then do |match|
        if match
          "#{match[1].strip}\n\n#{Wrap.call(match[2], length, comment_prefix).lstrip}"
        else
          text
        end
      end
    end

    def strip_comments(text, comment_prefix)
      text.gsub(/\n#{Regexp.escape(comment_prefix)}.*$/, "")
    end
  end
end
