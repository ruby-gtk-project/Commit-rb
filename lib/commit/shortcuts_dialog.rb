# frozen_string_literal: true

require_relative "i18n"

module Commit
  # The keyboard shortcuts window. Upstream uses GtkShortcutsWindow, which
  # GTK has since deprecated and whose Ruby constructor is broken anyway;
  # AdwShortcutsDialog is its replacement and shows the same list.
  class ShortcutsDialog
    include Translations

    EDITING = [
      ["Save and Confirm", "<Control>Return"],
      ["Cancel and Dismiss", "Escape"],
      ["Open Emoji Chooser", "<Control>period"],
      ["Move Current Line Up/Down", "<Alt>Up <Alt>Down"],
      ["Toggle Line Comment", "<Control>slash"],
      ["Select All", "<Control>a"],
      ["Unselect All", "<Shift><Control>a <Control>backslash"],
    ].freeze

    GENERAL = [
      ["Keyboard Shortcuts", "<Control>question"],
      ["Quit", "<Control>Q"],
    ].freeze

    def build
      dialog.tap do |d|
        d.add(editing_section)
        d.add(general_section)

        editing_section.tap do |section|
          EDITING.each { |title, accelerator| section.add(item(title, accelerator)) }
        end

        general_section.tap do |section|
          GENERAL.each { |title, accelerator| section.add(item(title, accelerator)) }
        end
      end
    end

    def present(parent)
      dialog.present(parent)
    end

    def item(title, accelerator) = Adwaita::ShortcutsItem.new(_(title), accelerator)

    def dialog = @dialog ||= Adwaita::ShortcutsDialog.new

    def editing_section
      @editing_section ||= Adwaita::ShortcutsSection.new.tap do |section|
        section.title = _("Editing")
      end
    end

    def general_section
      @general_section ||= Adwaita::ShortcutsSection.new.tap do |section|
        section.title = _("General")
      end
    end
  end
end
