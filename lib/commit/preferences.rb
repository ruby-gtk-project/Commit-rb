# frozen_string_literal: true

require_relative "i18n"
require_relative "preference_rows"

module Commit
  # Preferences for the current repository, written to its .gitconfig.
  class Preferences
    include Translations

    def initialize(on_close:)
      @on_close = on_close
    end

    attr_reader :on_close

    def build
      dialog.tap do |d|
        d.add(page)

        page.tap do |p|
          p.add(group)
          rows.add_to(group)
        end

        rows.load

        d.signal_connect("closed") do
          rows.save
          on_close.call
        end
      end
    end

    def present(parent)
      dialog.present(parent)
    end

    def rows = @rows ||= PreferenceRows.new(Settings.local)
    def dialog = @dialog ||= Adwaita::PreferencesDialog.new
    def page = @page ||= Adwaita::PreferencesPage.new

    def group
      @group ||= Adwaita::PreferencesGroup.new.tap do |g|
        g.description = _("For the current repository")
      end
    end
  end
end
