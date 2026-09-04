# frozen_string_literal: true

module Commit
  # Upstream has two entry points: the installed one, and src/local.js, which
  # runs the app straight out of the checkout with __DEV__ set. `bin/commit`
  # is the first; `bin/commit-dev` is the second.
  #
  # Dev mode marks both windows with libadwaita's `devel` styling, so a copy
  # running from a checkout is obvious, and adds an action to restart the app
  # in place.
  module Dev
    module_function

    def enable!
      @enabled = true
    end

    def enabled? = @enabled == true
  end
end
