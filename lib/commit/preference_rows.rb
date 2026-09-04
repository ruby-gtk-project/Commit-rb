# frozen_string_literal: true

require_relative "i18n"
require_relative "settings"

module Commit
  # The three preference rows, shared by the in-window preferences dialog
  # (which edits the repository's config) and the welcome window (which edits
  # the global one).
  class PreferenceRows
    include Translations

    def initialize(config)
      @config = config
    end

    attr_reader :config

    def add_to(group)
      group.tap do |g|
        g.add(title_length_row)
        g.add(capitalize_row)
        g.add(body_length_row)
      end
    end

    def load
      title_length_row.value = config.title_length_hint
      body_length_row.value = config.body_length_wrap
      capitalize_row.active = config.auto_capitalize_title
    end

    def save
      config.title_length_hint = title_length_row.value.to_i
      config.body_length_wrap = body_length_row.value.to_i
      config.auto_capitalize_title = capitalize_row.active?
      config.save
    end

    def title_length_row
      @title_length_row ||= spin_row(
        "Title Maximum Length (in characters)",
        MIN_TITLE_LENGTH_HINT,
        MAX_TITLE_LENGTH_HINT,
      )
    end

    def body_length_row
      @body_length_row ||= spin_row(
        "Body Lines Maximum Length (in characters)",
        MIN_BODY_LENGTH_WRAP,
        MAX_BODY_LENGTH_WRAP,
      )
    end

    def capitalize_row
      @capitalize_row ||= Adwaita::SwitchRow.new.tap do |row|
        row.title = _("Auto Capitalize Title")
      end
    end

    def spin_row(title, minimum, maximum)
      Gtk::Adjustment.new(
        minimum,
        minimum,
        maximum,
        1,
        10,
        0,
      ).then do |adjustment|
        Adwaita::SpinRow.new(adjustment, 1, 0).tap do |row|
          row.title = title
          row.numeric = true
        end
      end
    end
  end
end
