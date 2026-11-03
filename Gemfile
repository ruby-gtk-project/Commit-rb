# frozen_string_literal: true

# kettle-jem:freeze
# To retain chunks of comments & code during kettle-jem templating:
# Wrap custom sections with freeze markers (e.g., as above and below this comment chunk).
# kettle-jem will then preserve content between those markers across template runs.
# kettle-jem:unfreeze

source "https://rubygems.org"

git_source(:codeberg) { |repo_name| "https://codeberg.org/#{repo_name}" }
git_source(:gitlab) { |repo_name| "https://gitlab.com/#{repo_name}" }

#### IMPORTANT #######################################################
# Gemfile is for local development ONLY; Gemfile is NOT loaded in CI #
####################################################### IMPORTANT ####

# Include dependencies from commit-rb.gemspec
gemspec

# kettle-family 1.x requires Ruby >= 4.0, and the gemspec supports >= 3.4 — so
# on the Ruby the dev shell pins, asking for it fails version solving for the
# whole bundle, gtk4 and adwaita included, and nothing can be run at all. It is
# release tooling, not a runtime dependency, so it joins the bundle only on a
# Ruby that can have it.
if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("4.0")
  gem "kettle-family", "~> 1.3", ">= 1.3.37"
end

# Local workspace dependency wiring for *_local.gemfile overrides
gem "nomono", "~> 1.1", ">= 1.1.17", require: false # ruby >= 3.2.0

# Templating and the StructuredMerge family share this modular Gemfile.
# kettle-jem needs StructuredMerge to template, and kettle-changelog needs it at
# runtime (ast-crispr-markdown-markly -> markdown-merge -> tree_haver), so the
# test, lint, and release bundles resolve the family too. While the family is
# only partially released, registry copies pin the last published version exactly
# and cannot be satisfied alongside a local lockstep version, so a partial local
# wiring fails version solving for every command in the bundle.
#
# (env-switched: STRUCTUREDMERGE_DEV=/path/to/structuredmerge/ruby/gems for local paths)
eval_gemfile "gemfiles/modular/templating.gemfile" if
  ENV.fetch("K_JEM_TEMPLATING", "false").casecmp("true").zero? ||
  ENV.fetch("STRUCTUREDMERGE_DEV", "false").casecmp("false") != 0

# Debugging
eval_gemfile "gemfiles/modular/debug.gemfile"

# Code Coverage (env-switched: KETTLE_DEV_DEV=true for local paths)
eval_gemfile "gemfiles/modular/coverage.gemfile"

# Linting
eval_gemfile "gemfiles/modular/style.gemfile"

# Documentation
eval_gemfile "gemfiles/modular/documentation.gemfile"

# Changelog release tooling (available on Ruby versions supported by kettle-changelog)
eval_gemfile "gemfiles/modular/changelog.gemfile"

# Optional
eval_gemfile "gemfiles/modular/optional.gemfile"

### Std Lib Extracted Gems
eval_gemfile "gemfiles/modular/x_std_libs.gemfile"

# See unlocked_deps appraisal for more details on irb inclusion
gem "irb", "~> 1.17" # ruby >= 2.7
gem "gem_kit"
gem "adwaita"
gem "gettext"
gem "gtk4"

group :development do
  gem "rubocop"
end
