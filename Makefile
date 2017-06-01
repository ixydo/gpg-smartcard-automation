# vim:set ts=2 sw=2 sts=2 noexpandtab:

.PHONY: help
help:
	@echo "Usage: [GPGHOME=/path/to/gnupghome] make [TARGET]"
	@echo "Where:"
	@echo "  GPGHOME        the path to a folder containing existing keyrings"
	@echo
	@echo "Targets:"
	@echo "  all-soft (default) create a full set of keys: 1x master, 2x soft signing subkeys, 1x soft encryption subkey, 1x soft auth key"
	@echo
	@echo "  master           create a master key used to sign subkeys."
	@echo "  signing          a soft subkey used for signing only"
	@echo "  encryption       a soft subkey used for encryption only"
	@echo "  auth             a soft subkey used for authentication only"
	@echo
	@echo "  reset-yubikey    reset the GPG applet on a yubikey"
	@echo "  clean            Clean up previously created GNUPGHOME paths"
	@echo
	@echo "Not yet implemented targets:"
	@echo "  yubi-signing     generate a signing key on a yubikey"
	@echo "  yubi-encryption  generate an encryption key on a yubikey"
	@echo "  yubi-auth        generate an authentication key on a yubikey"
	@echo
	@echo "  flash-signing    flash a signing key to a yubikey"
	@echo "  flash-encryption flash an encryption key to a yubikey"
	@echo "  flash-auth       flash an encryption key to a yubikey"
	@auth
	@echo "Requirements:"
	@echo "  Only GPG >= 2.1 is supported."

KEYSET := $(MAKECMDGOALS)
ifeq ($(MAKECMDGOALS),signing)
	KEYSET := sign
	KEYTAG := S
else ifeq ($(MAKECMDGOALS),encryption)
	KEYSET := encr
	KEYTAG := E
else ifeq ($(MAKECMDGOALS),auth)
	KEYSET := auth
	KEYTAG := A
else
	KEYSET := UNSET
	KEYTAG := UNSET
endif

# Use the GPGHOME environment variable to define a fixed gnupg home folder.
GPGHOME ?= GPGHOME
ifeq ($(GPGHOME),GPGHOME)
	GNUPGHOME := $(shell /bin/date '+%F_%H%M')
else
	GNUPGHOME := $(GPGHOME)
endif

GPGBIN ?= gpg
GPGCMD ?= $(GPGBIN) --no-default-keyring --homedir .
GPG_VERSION_MAJOR = $(shell $(GPGCMD) --version 2>&1 | awk '/^gpg.*[0-9\.]+$$/ {print $$3}' | grep -Eo '^[0-9]')
GPG_VERSION_MINOR = $(shell $(GPGCMD) --version 2>&1 | awk '/^gpg.*[0-9\.]+$$/ {print $$3}' | sed -e 's/^[0-9]\.//' -e 's/\.[0-9]*$$//')

###
# Public goals
###
.PHONY: default
default: all-soft
	@echo "Your new keys are in $(GNUPGHOME)"
	@echo "TODO: more info here"

.PHONY: all-soft
all-soft: master
	$(MAKE) signing
	$(MAKE) encryption
	$(MAKE) auth

.PHONY: master
master: $(GNUPGHOME)/.data/key-master.asc

.PHONY: signing
signing: $(GNUPGHOME)/.data/subkey-sign.asc

.PHONY: encryption
encryption: $(GNUPGHOME)/.data/subkey-encr.asc

.PHONY: auth
auth: $(GNUPGHOME)/.data/subkey-auth.asc

# reset
reset-yubikey:
	@echo "Are you sure you want to reset the yubikey GPG applet?  This is a destructive"
	@echo "action and not reversible."
	@/bin/bash -c "read -p \"Type 'reset-yubikey' if you're sure you want to continue: \" ANS; \
	if [ \$$ANS == 'reset-yubikey' ]; then \
		echo 'gpg-connect-agent -r yubikey-reset.txt'; \
	fi"

# clean
.PHONY: clean
clean:
	@if [ $$(ls -1d $$(/bin/date '+%F_')* | wc -l) -eq 0 ]; then \
		echo "Nothing to clean.  Aborting."; \
		exit 1; \
	fi
	@echo "Will remove following paths:"; \
	ls -1d $$(/bin/date '+%F_%H')*; \
	echo "Continue (y/N)?"
	@read -n1 -s REPLY; \
	if [ $${REPLY} = 'y' ]; then \
		rm -rf $$(/bin/date '+%F_%H')*; \
		echo "Done."; \
	else \
		echo "Aborted."; \
	fi

###
# master key
###
$(GNUPGHOME)/.private-keys-v1.d: $(GNUPGHOME)/gpg.conf $(GNUPGHOME)/.data/config
	cd $(GNUPGHOME) && \
		source .data/config && \
		$(GPGCMD) --quick-generate-key "$${GPG_USER_ID}" "$${GPG_ALGO}" cert "$${MASTER_VALIDITY}"

$(GNUPGHOME)/.data/keyid-master.txt: $(GNUPGHOME)/.private-keys-v1.d
	cd $(GNUPGHOME) && \
		$(GPGCMD) --list-secret-keys | awk '/^sec/ {gsub("(rsa|elg|dsa|ecdh|ecdsa|eddsa)*[0-9]+R?/", "", $$2); print $$2}' > .data/keyid-master.txt

$(GNUPGHOME)/.data/keyfp-master.txt: $(GNUPGHOME)/.data/keyid-master.txt
	cd $(GNUPGHOME) && \
		$(GPGCMD) --list-secret-keys | awk -F= '/Key fingerprint/ {gsub(" ", "", $$2); print $$2}' > .data/keyfp-master.txt

$(GNUPGHOME)/.data/key-master.asc: $(GNUPGHOME)/.data/keyfp-master.txt
	cd $(GNUPGHOME) \
		&& $(GPGCMD) --armor --output .data/key-master.asc --export-secret-keys $(shell cat $(GNUPGHOME)/.data/keyid-master.txt)

	# TODO: Emit info about revocation cert and exported master key

###
# subkey
###
$(GNUPGHOME)/.data/subkeyid-$(KEYSET).txt: $(GNUPGHOME)/gpg.conf $(GNUPGHOME)/.data/config
	cd $(GNUPGHOME) && \
		source .data/config && \
		$(GPGCMD) --quick-add-key "$(shell cat $(GNUPGHOME)/.data/keyfp-master.txt)" "$${SUBKEY_ALGO}" "$(KEYSET)" "$${SUBKEY_VALIDITY}"
	cd $(GNUPGHOME) && \
		$(GPGCMD) --list-secret-keys | awk '/^ssb.*\[$(KEYTAG)\]/ {gsub("(rsa|elg|dsa|ecdh|ecdsa|eddsa|ed)*[0-9]+R?/", "", $$2); print $$2}' | head -n1 > .data/subkeyid-$(KEYSET).txt

$(GNUPGHOME)/.data/subkey-$(KEYSET).asc: $(GNUPGHOME)/.data/subkeyid-$(KEYSET).txt
	cd $(GNUPGHOME) \
		&& $(GPGCMD) --armor --output .data/subkey-$(KEYSET).asc --export-secret-subkeys "$(shell cat $(GNUPGHOME)/.data/subkeyid-$(KEYSET).txt)"

###
# Common, config and other phonies
###
$(GNUPGHOME)/gpg.conf: __common
	cp gpg.conf-sample $(GNUPGHOME)/gpg.conf

$(GNUPGHOME)/.data/config: __common
	cp config-sample $(GNUPGHOME)/.data/config
	$(EDITOR) $(GNUPGHOME)/.data/config

.PHONY: __common
__common: $(GNUPGHOME)/.data/gpg-version

.PHONY: $(GNUPGHOME)
$(GNUPGHOME)/.data:
		mkdir -p "$(GNUPGHOME)/.data"
		chmod 700 "$(GNUPGHOME)"

$(GNUPGHOME): $(GNUPGHOME)/.data

$(GNUPGHOME)/.data/gpg-version: $(GNUPGHOME)
	@if [ $(GPG_VERSION_MAJOR) -ge 2 ] && [ $(GPG_VERSION_MINOR) -ge 1 ]; then \
		echo "Found GnuPG $(GPG_VERSION_MAJOR).$(GPG_VERSION_MINOR)"; \
		gpg --version > $(GNUPGHOME)/.data/gpg-version 2>&1; \
	else \
		echo "GnuPG >= 2.1 is required, found GnuPG $(GPG_VERSION_MAJOR).$(GPG_VERSION_MINOR)"; \
		exit 1; \
	fi
