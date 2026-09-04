# frozen_string_literal: true

require_relative "commit/paths"

Commit::Paths.install_schemas!

require_relative "commit/dev"
require_relative "commit/gi"
require_relative "commit/application"
