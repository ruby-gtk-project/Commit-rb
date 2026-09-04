PREFIX ?= /usr/local
DESTDIR ?=

APP_ID := re.sonny.Commit
PKGDIR := $(DESTDIR)$(PREFIX)/share/$(APP_ID)
BINDIR := $(DESTDIR)$(PREFIX)/bin
DATADIR := $(DESTDIR)$(PREFIX)/share

LANGUAGES := $(notdir $(basename $(wildcard po/*.po)))

.PHONY: run test install uninstall flatpak bundle manifest clean

# Run out of the checkout, as a development build.
run:
	bundle exec ruby bin/commit-dev

test:
	bundle exec rubocop
	bundle exec ruby test/test_scm.rb
	bundle exec ruby test/test_translations.rb
	env -u DISPLAY -u WAYLAND_DISPLAY bundle exec ruby test/drive_editor.rb
	env -u DISPLAY -u WAYLAND_DISPLAY bundle exec ruby test/drive_welcome.rb
	env -u DISPLAY -u WAYLAND_DISPLAY bundle exec ruby test/drive_dev.rb
	appstreamcli validate --no-net data/$(APP_ID).metainfo.xml
	desktop-file-validate --no-hints data/$(APP_ID).desktop
	find po/ -type f -name "*.po" -print0 | xargs -0 -n1 msgfmt -o /dev/null --check
	flatpak-builder --show-manifest $(APP_ID).json > /dev/null

# lib/ and data/ stay siblings so lib/commit/paths.rb finds the data next to
# it, exactly as it does in the checkout.
install:
	install -d $(PKGDIR)/lib $(PKGDIR)/data $(PKGDIR)/bin $(BINDIR)
	cp -r lib/. $(PKGDIR)/lib/
	cp -r data/. $(PKGDIR)/data/
	install -m 755 bin/commit $(PKGDIR)/bin/commit
	install -m 755 bin/commit-dev $(PKGDIR)/bin/commit-dev
	glib-compile-schemas --strict $(PKGDIR)/data
	for language in $(LANGUAGES); do \
		install -d $(PKGDIR)/data/locale/$$language/LC_MESSAGES; \
		msgfmt --output $(PKGDIR)/data/locale/$$language/LC_MESSAGES/$(APP_ID).mo po/$$language.po; \
	done
	printf '#!/bin/sh\nexec %s/bin/commit "$$@"\n' '$(PREFIX)/share/$(APP_ID)' > $(BINDIR)/commit
	chmod 755 $(BINDIR)/commit
	install -Dm 644 data/$(APP_ID).desktop $(DATADIR)/applications/$(APP_ID).desktop
	install -Dm 644 data/$(APP_ID).metainfo.xml $(DATADIR)/metainfo/$(APP_ID).metainfo.xml
	install -Dm 644 data/$(APP_ID).gschema.xml $(DATADIR)/glib-2.0/schemas/$(APP_ID).gschema.xml
	install -Dm 644 data/icons/hicolor/scalable/apps/$(APP_ID).svg \
		$(DATADIR)/icons/hicolor/scalable/apps/$(APP_ID).svg
	install -Dm 644 data/icons/hicolor/symbolic/apps/$(APP_ID)-symbolic.svg \
		$(DATADIR)/icons/hicolor/symbolic/apps/$(APP_ID)-symbolic.svg

uninstall:
	rm -rf $(PKGDIR)
	rm -f $(BINDIR)/commit
	rm -f $(DATADIR)/applications/$(APP_ID).desktop
	rm -f $(DATADIR)/metainfo/$(APP_ID).metainfo.xml
	rm -f $(DATADIR)/glib-2.0/schemas/$(APP_ID).gschema.xml
	rm -f $(DATADIR)/icons/hicolor/scalable/apps/$(APP_ID).svg
	rm -f $(DATADIR)/icons/hicolor/symbolic/apps/$(APP_ID)-symbolic.svg

# Regenerate the manifest after changing the Gemfile: every gem is pinned in
# it by name and checksum.
manifest:
	bundle cache --no-install
	bundle exec ruby tools/generate-flatpak-manifest.rb

flatpak:
	flatpak-builder --user --force-clean --repo=repo --install-deps-from=flathub \
		flatpak $(APP_ID).json
	flatpak --user remote-add --no-gpg-verify --if-not-exists Commit repo
	flatpak --user install --reinstall --assumeyes Commit $(APP_ID)

bundle:
	flatpak-builder --user --force-clean --repo=repo --install-deps-from=flathub \
		flatpak $(APP_ID).json
	flatpak build-bundle repo Commit.flatpak $(APP_ID) \
		--runtime-repo=https://flathub.org/repo/flathub.flatpakrepo

clean:
	rm -rf tmp data/locale data/gschemas.compiled flatpak repo .flatpak-builder Commit.flatpak
