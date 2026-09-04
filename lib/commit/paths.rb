# frozen_string_literal: true

module Commit
  APPLICATION_ID = "re.sonny.Commit"
  RESOURCE_PATH = "/re/sonny/Commit"
  VERSION = "4.6"

  # Where the gschema, the CSS and the GtkSourceView language definitions live.
  module Paths
    module_function

    def data_dir = File.expand_path("../../data", __dir__)

    def language_specs_dir = File.join(data_dir, "language-specs")

    def style_css = File.join(data_dir, "style.css")

    def icons_dir = File.join(data_dir, "icons")

    def locale_dir = File.join(data_dir, "locale")

    def po_dir = File.expand_path("../../po", __dir__)

    # GSettings will not open a schema it cannot find on disk, and running
    # from a checkout there is no installed copy — so compile the source
    # schema in place the first time and point GSettings at it.
    def install_schemas!
      File.join(data_dir, "gschemas.compiled").then do |compiled|
        if !File.exist?(compiled) || File.mtime(schema_source) > File.mtime(compiled)
          compile_schemas!
        end
      end

      ENV["GSETTINGS_SCHEMA_DIR"] = [data_dir, ENV.fetch("GSETTINGS_SCHEMA_DIR", nil)].compact.join(":")
    end

    def schema_source = File.join(data_dir, "#{APPLICATION_ID}.gschema.xml")

    def compile_schemas!
      system(
        "glib-compile-schemas",
        "--strict",
        data_dir,
        exception: true,
      )
    end
  end
end
