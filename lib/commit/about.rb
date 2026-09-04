# frozen_string_literal: true

require_relative "i18n"
require_relative "paths"

module Commit
  # The about dialog.
  class About
    include Translations

    DEVELOPERS = ["Sonny Piers https://sonny.re", "Aral Balkan https://ar.al/"].freeze
    ARTISTS = ["Tobias Bernard <tbernard@gnome.org>"].freeze
    CONTRIBUTORS = [
      "Sergey Bugaev https://floss.social/@bugaevc",
      "Christopher Davis https://social.libre.fi/brainblasted",
      "axtlos https://github.com/axtloss",
      "Felipe Kinoshita https://mastodon.social/@fkinoshita",
      "EncryptedEasty https://github.com/EncryptedEasty",
    ].freeze

    def build
      dialog.tap do |d|
        d.add_credit_section("Contributors", CONTRIBUTORS)
      end
    end

    def present(parent)
      dialog.present(parent)
    end

    def dialog
      @dialog ||= Adwaita::AboutDialog.new.tap do |d|
        d.application_name = "Commit"
        d.application_icon = APPLICATION_ID
        d.version = VERSION
        d.developers = DEVELOPERS
        d.artists = ARTISTS
        d.copyright = "© 2020-2025 Sonny Piers\n© 2018-2020 Aral Balkan"
        d.license_type = Gtk::License::GPL_3_0
        d.website = "https://commit.sonny.re"
        d.issue_url = "https://commit.sonny.re/feedback"
        # TRANSLATORS: eg. 'Translator Name <you@example.com>' or a website.
        d.translator_credits = _("translator-credits")
      end
    end
  end
end
