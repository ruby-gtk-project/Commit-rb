# frozen_string_literal: true

# po/POTFILES is the list xgettext walks to build the catalogue template, so a
# path that does not exist stops extraction and a file left off it silently
# drops every string in it. Upstream's POTFILES names .js and .blp files; the
# port's names .rb and .ui ones, and nothing but this checks that it still
# names the right ones.
#
#   bundle exec ruby test/test_potfiles.rb

require "gettext/tools/xgettext"
require "tmpdir"

ROOT = File.expand_path("..", __dir__)

# `_("…")` and `N_("…")`, but not `bind_textdomain_codeset("…")`.
GETTEXT_CALL = /(?<![A-Za-z0-9_])N?_\("/

# The six confirm-button labels. Scm chooses them and Window translates them,
# so they reach xgettext only through N_ — see lib/commit/scm.rb.
ACTION_MSGIDS = ["_Commit", "_Merge", "_Tag", "A_dd", "_Rebase", "_Save"].freeze

$failures = []
$checks = 0

def check(description, actual, expected)
  $checks += 1
  if actual == expected
    puts "  ok   #{description}"
  else
    puts "  FAIL #{description}"
    puts "       expected: #{expected.inspect}"
    puts "       actual:   #{actual.inspect}"
    $failures << description
  end
end

def listed
  File.readlines(File.join(ROOT, "po/POTFILES"), chomp: true).reject(&:empty?)
end

def relative(path) = path.delete_prefix("#{ROOT}/")

# Every Ruby file that calls into gettext has strings to extract.
def ruby_sources_with_strings
  Dir.glob(File.join(ROOT, "lib/**/*.rb")).select do |path|
    File.read(path).match?(GETTEXT_CALL)
  end.map { |path| relative(path) }.sort
end

# GtkBuilder marks its own, and GtkBuilder files are XML rather than Ruby, so
# they are extracted by the C xgettext and matched here on the same attribute.
def ui_sources_with_strings
  Dir.glob(File.join(ROOT, "data/*.ui")).select do |path|
    File.read(path).include?('translatable="yes"')
  end.map { |path| relative(path) }.sort
end

# Extraction over the listed Ruby files, which is what a catalogue refresh
# does. The .ui and metadata entries are not Ruby and rxgettext cannot parse
# them, so they sit this one out.
def extracted_msgids
  Dir.mktmpdir do |dir|
    File.join(dir, "test.pot").then do |pot|
      Dir.chdir(ROOT) do
        GetText::Tools::XGetText.run("-o", pot, *listed.grep(/\.rb\z/))
      end

      File.read(pot).scan(/^msgid "(.+)"$/).flatten
    end
  end
end

puts "POTFILES paths"
listed.each do |path|
  check(path, File.exist?(File.join(ROOT, path)), true)
end

puts
puts "nothing with strings is left off"
check("ruby sources", ruby_sources_with_strings - listed, [])
check("ui files", ui_sources_with_strings - listed, [])

puts
puts "extraction"
extracted_msgids.then do |msgids|
  ACTION_MSGIDS.each do |msgid|
    check("#{msgid} is extractable", msgids.include?(msgid), true)
  end
end

puts
puts "#{$checks - $failures.length} of #{$checks} checks passed"
exit($failures.empty? ? 0 : 1)
