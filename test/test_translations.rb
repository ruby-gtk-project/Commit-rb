# frozen_string_literal: true

# The twenty upstream catalogues are compiled and bound. Run under a locale
# that has translations and check a few of them come back.
#
#   bundle exec ruby test/test_translations.rb

ENV["LANGUAGE"] = "fr"

require_relative "../lib/commit/i18n"
require_relative "../lib/commit/scm"

class FrenchStrings
  include Commit::Translations

  def lookup(message) = _(message)
end

$failures = []
$checks = 0

def check(description, actual, expected)
  $checks += 1
  if actual == expected
    puts "  ok   #{description}"
  else
    puts "  FAIL #{description}: expected #{expected.inspect}, got #{actual.inspect}"
    $failures << description
  end
end

strings = FrenchStrings.new

check("catalogues were compiled", Dir.exist?(File.join(Commit::Paths.locale_dir, "fr")), true)
check("menu item", strings.lookup("Preferences"), "Préférences")
check("shortcuts window", strings.lookup("Keyboard Shortcuts"), "Raccourcis clavier")
check("header button", strings.lookup("_Abort"), "_Abandonner")
check("welcome button", strings.lookup("Copy to Clipboard"), "Copier dans le presse-papiers")
check("shortcuts section", strings.lookup("General"), "Général")
check("about menu item", strings.lookup("About Commit"), "À propos de Commit")
check("confirm button label", strings.lookup(Commit::Scm.action_for("unknown")), "_Enregistrer")
check(
  "even the documentation link is localized",
  strings.lookup("https://git-scm.com/book/en/v2/Customizing-Git-Git-Configuration#_core_editor"),
  "https://git-scm.com/book/fr/v2/Personnalisation-de-Git-Configuration-de-Git#_core_editor",
)
check("a string the catalogue has no entry for falls through", strings.lookup("Discard changes?"), "Discard changes?")

puts
puts "#{$checks - $failures.length} of #{$checks} checks passed"
exit($failures.empty? ? 0 : 1)
