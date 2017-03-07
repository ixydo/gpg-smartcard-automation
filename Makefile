ifeq ($(MAKECMDGOALS),signing)
	KEYSET := signing
else
	KEYSET := signing+encryption
endif

# Use the GPGHOME environment variable to define a fixed gnupg home folder.
GPGHOME ?= GPGHOME
ifeq ($(GPGHOME),GPGHOME)
	GNUPGHOME := $(shell /bin/date '+%F_%H%M')_$(KEYSET)
else
	GNUPGHOME := $(GPGHOME)
endif

# We require GPG 2.1 or greater
GPGCMD := /usr/local/gnupg-2.1/bin/gpg --no-default-keyring --homedir . --keyring pubring.kbx

# VIRTUAL PHONIES
.PHONY: default
default: signing+encryption
	@echo "Your new keys are in $(GNUPGHOME)"

.PHONY: signing+encryption
signing+encryption: $(GNUPGHOME)/signing-key.asc $(GNUPGHOME)/encryption-key.asc $(GNUPGHOME)/revoke.txt

.PHONY: signing
signing: $(GNUPGHOME)/signing-key.asc $(GNUPGHOME)/revoke.txt

.PHONY: import
import:
	cd $(GNUPGHOME) \
			&& $(GPGCMD) --import ../$(IMPORT)

# THE REAL DEAL
$(GNUPGHOME)/encryption-key.asc: $(GNUPGHOME)/subkeyid.txt
	cd $(GNUPGHOME) \
		&& $(GPGCMD) --armor --export-secret-subkeys $(shell cat $(GNUPGHOME)/subkeyid.txt) > encryption-key.asc

$(GNUPGHOME)/signing-key.asc: $(GNUPGHOME)/keyid.txt
	cd $(GNUPGHOME) \
		&& $(GPGCMD) --armor --export-secret-keys $(shell cat $(GNUPGHOME)/keyid.txt) > signing-key.asc

$(GNUPGHOME)/revoke.txt: $(GNUPGHOME)/keyid.txt
	cd $(GNUPGHOME) \
		&& $(GPGCMD) --gen-revoke $(shell cat $(GNUPGHOME)/keyid.txt) > revoke.txt

$(GNUPGHOME)/subkeyid.txt: $(GNUPGHOME)/keyid.txt
	cd $(GNUPGHOME) && $(GPGCMD) --list-secret-keys | awk '/^ssb/ {gsub("(rsa|elg|dsa|ecdh|ecdsa|eddsa)[0-9]+/", "", $$2); print $$2}' > subkeyid.txt

$(GNUPGHOME)/keyid.txt: $(GNUPGHOME)/gpg.conf $(GNUPGHOME)/genkey-$(KEYSET).conf
	cd $(GNUPGHOME) && $(GPGCMD) --batch --gen-key genkey-$(KEYSET).conf
	cd $(GNUPGHOME) && $(GPGCMD) --list-secret-keys | awk '/^sec/ {gsub("(rsa|elg|dsa|ecdh|ecdsa|eddsa)[0-9]+/", "", $$2); print $$2}' > keyid.txt
	cd $(GNUPGHOME) && $(GPGCMD) --change-passphrase $(shell awk '/^Name-Email/ {print $$2 }' $(GNUPGHOME)/genkey-$(KEYSET).conf)

$(GNUPGHOME)/genkey-$(KEYSET).conf:
	cp genkey-$(KEYSET).conf-sample $(GNUPGHOME)/genkey-$(KEYSET).conf
	chmod 600 $(GNUPGHOME)/genkey-$(KEYSET).conf
	$(EDITOR) $(GNUPGHOME)/genkey-$(KEYSET).conf

$(GNUPGHOME)/gpg.conf: common
	cp gpg.conf-sample $(GNUPGHOME)/gpg.conf

# OTHER PHONIES
.PHONY: common
common:
	[ ! -d "$(GNUPGHOME)" ]; mkdir -p "$(GNUPGHOME)"; chmod 700 "$(GNUPGHOME)"

.PHONY: help
help:
	@echo "Usage: [GPGHOME=/path/to/gnupghome] make [signing|signing+encryption]"
	@echo "Where:"
	@echo "  GPGHOME   is the path to a folder containing existing keyrings"
	@echo "And the default target is 'signing+encryption'"
