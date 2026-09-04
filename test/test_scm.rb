# frozen_string_literal: true

# Parity checks for the message parsing, ported from the upstream
# test/scm.test.js and test/wrap.test.js against the same fixtures.
#
#   bundle exec ruby test/test_scm.rb

require_relative "../lib/commit/scm"
require_relative "../lib/commit/wrap"

FIXTURES = File.expand_path("fixtures", __dir__)

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

def fixture(name) = File.read(File.join(FIXTURES, name))

def parsed(name, type) = Commit::Scm.parse(fixture(name), type)

def wrap(text, width, prefix) = Commit::Wrap.call(text, width, prefix)

puts "wrap"
check("preserves newlines 1", wrap("hello\nworld", 100, "#"), "hello\nworld")
check("preserves newlines 2", wrap("\nhello\nworld\n", 100, "#"), "\nhello\nworld\n")
check("preserves newlines 3", wrap("hello\nworld\n", 100, "#"), "hello\nworld\n")
check("preserves newlines 4", wrap("\nhello\nworld", 100, "#"), "\nhello\nworld")
check("no whitespace to wrap at", wrap("idonthaveanywhitespace", 6, "#"), "idonthaveanywhitespace")
check("leaves comment lines", wrap("# please don't wrap me", 4, "#"), "# please don't wrap me")
check("wraps at closest whitespace 1", wrap("hello world", 6, "#"), "hello\nworld")
check("wraps at closest whitespace 2", wrap("hello world", 5, "#"), "hello\nworld")
check(
  "wraps a long line",
  wrap("hello world this is a very long message, let's see what happens", 10, "#"),
  "hello\nworld this\nis a very\nlong\nmessage,\nlet's see\nwhat\nhappens",
)

"I should not be wrapped at a #word starting with commit prefix or it will become a comment".then do |str|
  check(
    "never wraps onto a comment prefix",
    wrap(str, str.index("#"), "#"),
    "I should not be wrapped at\na #word starting with commit\nprefix or it will become a\ncomment",
  )
end
check("no room to avoid the prefix", wrap("1234567890#1234567890", 10, "#"), "1234567890#1234567890")

puts "format"
check(
  "wraps the body and leaves the title and comments alone",
  Commit::Scm.format(fixture("format_input.txt"), 75, "#"),
  fixture("format_expected.txt"),
)

puts "type_for"
{
  "/foo/bar/addp-hunk-edit.diff"          => "add -p",
  "/foo/bar/COMMIT_EDITMSG"               => "commit",
  "/foo/bar/rebase-merge/git-rebase-todo" => "rebase",
  "/foo/bar/MERGE_MSG"                    => "merge",
  "/foo/bar/TAG_EDITMSG"                  => "tag",
  "/foo/bar/hg-editor-foo.commit.hg.txt"  => "hg",
  "/foo/bar/.gitconfig"                   => "config",
  "/foo/bar/git/config"                   => "config",
  "/foo/bar/.git/config"                  => "config",
  "/foo/bar/.hgrc"                        => "config",
  "/foo/bar/.hg/hgrc-not-shared"          => "config",
  "/foo/bar/.hg/hgrc"                     => "config",
  "/foo/bar/hg/hgrc"                      => "config",
  "/foo/bar/something-else"               => nil,
}.each do |path, type|
  check(path, Commit::Scm.type_for(path), type)
end

puts "empty_commit_message?"
[
  ["foo\n#hello", false],
  ["foo", false],
  ["# hello\nfoo", false],
  ["", true],
  ["# hello", true],
  [" ", true],
  [" \n#\n ", true],
].each do |text, expected|
  check(text.inspect, Commit::Scm.empty_commit_message?(text, "#"), expected)
end

puts "parse"
check(
  "add -p body",
  parsed("addp-hunk-edit.diff", "add -p")[:body],
  "# Manual hunk edit mode -- see bottom for a quick guide.\n@@ -1,3 +1,4 @@\n d\n b\n c\n+e",
)
check("add -p detail", parsed("addp-hunk-edit.diff", "add -p")[:detail], nil)
check("add -p comment prefix", parsed("addp-hunk-edit.diff", "add -p")[:comment_prefix], "#")
check("add -p cursor", parsed("addp-hunk-edit.diff", "add -p")[:cursor_position], 0)
check("add -p language", parsed("addp-hunk-edit.diff", "add -p")[:language], "diff")
check("add -p is not a message", parsed("addp-hunk-edit.diff", "add -p")[:is_message], false)

check("merge body", parsed("MERGE_MSG", "merge")[:body], "Merge branch 'test'")
check("merge detail", parsed("MERGE_MSG", "merge")[:detail], "branch test")
check("merge cursor", parsed("MERGE_MSG", "merge")[:cursor_position], 19)
check("merge action", parsed("MERGE_MSG", "merge")[:action], "_Merge")

check(
  "commit with body",
  parsed("with-body/COMMIT_EDITMSG", "commit")[:body],
  "Do something great with this commit message, perhaps tell of your adventures?" \
  "\n\nThis is another line.",
)
check("commit with body detail", parsed("with-body/COMMIT_EDITMSG", "commit")[:detail], "main")
check("commit with body cursor", parsed("with-body/COMMIT_EDITMSG", "commit")[:cursor_position], 100)

check(
  "commit containing an octothorpe",
  parsed("with-octohorpe/COMMIT_EDITMSG", "commit")[:body],
  "Implement awesome new feature\n\nCloses #123",
)
check("octothorpe detail", parsed("with-octohorpe/COMMIT_EDITMSG", "commit")[:detail], "master")
check("octothorpe cursor", parsed("with-octohorpe/COMMIT_EDITMSG", "commit")[:cursor_position], 42)

check("commit without body", parsed("without-body/COMMIT_EDITMSG", "commit")[:body], "")
check("without body detail", parsed("without-body/COMMIT_EDITMSG", "commit")[:detail], "main")
check("without body cursor", parsed("without-body/COMMIT_EDITMSG", "commit")[:cursor_position], 0)

check(
  "rebase todo body",
  parsed("rebase-merge/git-rebase-todo", "rebase")[:body],
  "pick f353b3a this commit message is too long please fix me! wow so long commit message! damn!" \
  "\npick 688174c Im ok",
)
check(
  "rebase detail",
  parsed("rebase-merge/git-rebase-todo", "rebase")[:detail],
  "d44e355..688174c → d44e355",
)
check("rebase cursor", parsed("rebase-merge/git-rebase-todo", "rebase")[:cursor_position], 0)
check("rebase action", parsed("rebase-merge/git-rebase-todo", "rebase")[:action], "_Rebase")

check("tag body", parsed("TAG_EDITMSG", "tag")[:body], "")
check("tag detail", parsed("TAG_EDITMSG", "tag")[:detail], "1.0.0")
check("tag cursor", parsed("TAG_EDITMSG", "tag")[:cursor_position], 0)

check("hg without body", parsed("hg-editor-without_body.commit.hg.txt", "hg")[:body], "")
check("hg without body detail", parsed("hg-editor-without_body.commit.hg.txt", "hg")[:detail], "default")
check("hg comment prefix", parsed("hg-editor-without_body.commit.hg.txt", "hg")[:comment_prefix], "HG:")
check("hg language", parsed("hg-editor-without_body.commit.hg.txt", "hg")[:language], "hg")
check("hg without body cursor", parsed("hg-editor-without_body.commit.hg.txt", "hg")[:cursor_position], 0)

check(
  "hg with body",
  parsed("hg-editor-with_body.commit.hg.txt", "hg")[:body],
  "foo this is great\n\nhello",
)
check("hg with body detail", parsed("hg-editor-with_body.commit.hg.txt", "hg")[:detail], "default")
check("hg with body cursor", parsed("hg-editor-with_body.commit.hg.txt", "hg")[:cursor_position], 24)

check(
  "squashed merge is detected",
  parsed("git-merge-squash/COMMIT_EDITMSG", "commit")[:cursor_position],
  0,
)
check("squashed merge has no detail", parsed("git-merge-squash/COMMIT_EDITMSG", "commit")[:detail], nil)
check(
  "squashed merge is still a message",
  parsed("git-merge-squash/COMMIT_EDITMSG", "commit")[:is_message],
  true,
)
check(
  "squashed rebase is detected",
  parsed("git-rebase-squash/COMMIT_EDITMSG", "commit")[:cursor_position],
  0,
)
check("squashed rebase has no detail", parsed("git-rebase-squash/COMMIT_EDITMSG", "commit")[:detail], nil)

puts "parse — empty files"
{
  "empty/addp-hunk-edit.diff" => "add -p",
  "empty/COMMIT_EDITMSG"      => "commit",
  "empty/git-rebase-todo"     => "rebase",
  "empty/MERGE_MSG"           => "merge",
  "empty/TAG_EDITMSG"         => "tag",
}.each do |name, type|
  check("#{name} body", parsed(name, type)[:body], "")
  check("#{name} detail", parsed(name, type)[:detail], nil)
  check("#{name} comment", parsed(name, type)[:comment], "")
  check("#{name} cursor", parsed(name, type)[:cursor_position], 0)
end

puts "parse — config"
Commit::Scm.parse("[user]\n\tname = x\n", "config").then do |config|
  check("config body is the whole file", config[:body], "[user]\n\tname = x\n")
  check("config has no comment", config[:comment], "")
  check("config language", config[:language], "ini")
  check("config is not a message", config[:is_message], false)
  check("config action", config[:action], "_Save")
end

puts
puts "#{$checks - $failures.length} of #{$checks} checks passed"
$failures.each { |failure| puts "  failed: #{failure}" }
exit($failures.empty? ? 0 : 1)
