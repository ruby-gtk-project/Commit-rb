# frozen_string_literal: true

require "fiddle"
require "fileutils"
require "gettext"
require "gettext/tools/msgfmt"

require_relative "paths"

module Commit
  # Upstream ships translations in twenty languages; they are the same
  # catalogues, compiled from po/ into data/locale/ the first time the app
  # runs from a checkout rather than an install.
  module Catalogues
    module_function

    # An installed copy ships the compiled catalogues and no po/, so there is
    # nothing to do; a checkout compiles them on the way past.
    def install!
      Dir.glob(File.join(Paths.po_dir, "*.po")).each do |po|
        compile(po, mo_path_for(po))
      end
    end

    def mo_path_for(po)
      File.basename(po, ".po").then do |language|
        File.join(
          Paths.locale_dir,
          language,
          "LC_MESSAGES",
          "#{APPLICATION_ID}.mo",
        )
      end
    end

    def compile(po, mo)
      if !File.exist?(mo) || File.mtime(po) > File.mtime(mo)
        FileUtils.mkdir_p(File.dirname(mo))
        quietly { GetText::Tools::MsgFmt.run("--output", mo, po) }
      end
    rescue SystemCallError => e
      warn("Could not compile #{po}: #{e.message}")
    end

    # GtkBuilder translates through C gettext, not the gem's, so the domain
    # has to be bound on that side too or the .ui files come out in English.
    def bind_c_domain!
      Fiddle::Handle.new(nil).then do |libc|
        Fiddle::Function.new(
          libc["bindtextdomain"],
          [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
          Fiddle::TYPE_VOIDP,
        ).call(APPLICATION_ID, Paths.locale_dir)

        Fiddle::Function.new(
          libc["bind_textdomain_codeset"],
          [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
          Fiddle::TYPE_VOIDP,
        ).call(APPLICATION_ID, "UTF-8")
      end
    end

    # msgfmt reports every obsolete msgid in every catalogue on stderr, which
    # is thirty lines of noise on a first run and tells us nothing.
    def quietly
      original = $stderr.dup
      $stderr.reopen(File::NULL)
      yield
    ensure
      $stderr.reopen(original)
    end
  end
end

# The catalogues have to exist before the domain is bound: gettext resolves
# the .mo file once and remembers that there wasn't one.
Commit::Catalogues.install!
Commit::Catalogues.bind_c_domain!

module Commit
  # `include Translations` (or `extend` it, in a module of module functions)
  # is what gives a class its `_()`.
  module Translations
    include GetText
    bindtextdomain(APPLICATION_ID, path: Paths.locale_dir)
  end
end
