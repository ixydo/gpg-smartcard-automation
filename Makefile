# vim:set ts=2 sw=2 sts=2 noexpandtab:
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

GPGCMD ?= /usr/local/gnupg-2.1/bin/gpg --no-default-keyring --homedir .
GPGCMD ?= /usr/local/Cellar/gnupg2/2.0.30_3/bin/gpg2 --no-default-keyring --keyring ./pubring.gpg --homedir .

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
	cd $(GNUPGHOME) && $(GPGCMD) --list-secret-keys | awk '/^ssb/ {gsub("(rsa|elg|dsa|ecdh|ecdsa|eddsa)*[0-9]+R?/", "", $$2); print $$2}' > subkeyid.txt

$(GNUPGHOME)/keyid.txt: $(GNUPGHOME)/gpg.conf $(GNUPGHOME)/genkey-$(KEYSET).conf
	cd $(GNUPGHOME) && $(GPGCMD) --batch --gen-key genkey-$(KEYSET).conf
	cd $(GNUPGHOME) && $(GPGCMD) --list-secret-keys | awk '/^sec/ {gsub("(rsa|elg|dsa|ecdh|ecdsa|eddsa)*[0-9]+R?/", "", $$2); print $$2}' > keyid.txt
	killall gpg-agent || :
	cd $(GNUPGHOME) && /usr/local/Cellar/gpg-agent/2.0.30_1/bin/gpg-agent --daemon --write-env-file .gpg-agent-info --pinentry-program /usr/local/MacGPG2/libexec/pinentry-mac.app/Contents/MacOS/pinentry-mac --default-cache-ttl 60 --max-cache-ttl 120 --homedir . --use-standard-socket
	sleep 1
	eval $(shell cat $(GNUPGHOME)/.gpg-agent-info)
	cd $(GNUPGHOME) && $(shell cat $(GNUPGHOME)/.gpg-agent-info) $(GPGCMD) --passwd $(shell awk '/^Name-Email/ {print $$2 }' $(GNUPGHOME)/genkey-$(KEYSET).conf)
	killall gpg-agent || :

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
