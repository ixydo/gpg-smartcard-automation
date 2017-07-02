# vim:set ts=2 sw=2 sts=2 noexpandtab:

.PHONY: help
help:
	@echo "Usage: [GPGHOME=/path/to/gnupghome] make [TARGET]"
	@echo "Where:"
	@echo "  GPGHOME          the path to a folder containing existing keyrings"
	@echo
	@echo "Targets:"
	@echo "  default          create a soft master key and encryption subkey, then"
	@echo "                   initialise two smartcards with signing and auth subkeys"
	@echo "                   and the soft encryption key."
	@echo
	@echo "  softkeys         (default) create a full set of keys: master, soft signing"
	@echo "                   subkey, soft encryption subkey, soft auth key."
	@echo
	@echo "  master           create a master key used to sign subkeys."
	@echo "  signing          a soft subkey used for signing only"
	@echo "  encryption       a soft subkey used for encryption only"
	@echo "  auth             a soft subkey used for authentication only"
	@echo
	@echo "  show             Display secret key information for temporary working path,"
	@echo "                   and card status."
	@echo
	@echo "  remove-master    Backup and remove the private master key from the keychain"
	@echo "                   in $(GNUPGHOME)"
	@echo
	@echo "  import-ssb FILE  Import secret subkeys in FILE and link to SmartCard"
	@echo
	@echo "  test             Perform a sign and encrypt, and a decrypt and verify to confirm"
	@echo "                   all is functioning as expected."
	@echo
	@echo "  reset-yubikey    reset the GPG applet on a yubikey"
	@echo "  clean            Clean up previously created GNUPGHOME paths"
	@echo
	@echo "Requirements:"
	@echo "  Only GPG >= 2.1 is supported."

KEYSET := $(MAKECMDGOALS)
ifeq ($(findstring signing, $(MAKECMDGOALS)),signing)
	KEYSET := sign
	KEYTAG := S
else ifeq ($(findstring encryption, $(MAKECMDGOALS)),encryption)
	KEYSET := encr
	KEYTAG := E
else ifeq ($(findstring auth, $(MAKECMDGOALS)),auth)
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
default: master encryption sckey import-encr sckey test
	@echo "🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 "
	@echo "Your keys have been generated."
	@echo
	@echo "💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 💾 "
	@echo "You'll should now back up $(GNUPGHOME) to an encrypted SLC USB stick or"
	@echo "two.  Remember this USB stick will contain your original master key,"
	@echo "revocation certificates, and original soft subkeys, such as your"
	@echo "encryption key."
	@echo
	@echo "🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 🖨 "
	@echo "You can also print out your key backups and store them in a safe"
	@echo "place.  The files are at:"
	@echo " - $(GNUPGHOME)/.data/paperkey-master.txt"
	@echo " - $(GNUPGHOME)/.data/paperkey-subkey-*.txt"
	@echo
	@echo "⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ "
	@echo "Your keys, both master and subkeys, are set to expire.  To extend their"
	@echo "validity you'll need to use the master key."
	@echo
	@echo "🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 "
	@echo "Finally, you'll want to transfer the following files to your regular"
	@echo "device and import the subkeys into your regular ~/.gnupg keychain."
	@echo " - $(GNUPGHOME)/.data/subkeys.asc"
	@echo " - $(GNUPGHOME)/.data/id_rsa.pub"
	@echo

.PHONY: softkeys
softkeys: master
	$(MAKE) signing
	$(MAKE) encryption
	$(MAKE) auth

.PHONY: master
master: $(GNUPGHOME)/.data/paperkey-master.txt

.PHONY: signing
signing: $(GNUPGHOME)/.data/subkey-sign.asc

.PHONY: encryption
encryption: $(GNUPGHOME)/.data/subkey-encr.asc

.PHONY: auth
auth: $(GNUPGHOME)/.data/id_rsa.pub

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
	@if [ -d "$(GNUPGHOME)" ]; then \
		echo "Will remove following path: $(GNUPGHOME)"; \
		echo "Continue (y/N)?"; \
		read -n1 -s REPLY; \
		if [ $${REPLY} = 'y' ]; then \
			rm -rf "./$(GNUPGHOME)"; \
			echo "Done."; \
		else \
			echo "Aborted."; \
		fi \
	fi
	@if [ $$(ls -1d $$(/bin/date '+%F_')* 2>/dev/null | wc -l) -eq 0 ]; then \
		echo "No auto-generated folders to clean."; \
	else \
		@echo "Will remove following paths:"; \
		ls -1d $$(/bin/date '+%F_%H')*; \
		echo "Continue (y/N)?" \
		read -n1 -s REPLY; \
		if [ $${REPLY} = 'y' ]; then \
			rm -rf "./$$(/bin/date '+%F_%H')*"; \
			echo "Done."; \
		else \
			echo "Aborted."; \
		fi \
	fi

.PHONY: show
show:
	cd $(GNUPGHOME) && \
		$(GPGCMD) --list-secret-keys
	$(GPGBIN) --card-status

###
# master key
###
$(GNUPGHOME)/private-keys-v1.d: $(GNUPGHOME)/gpg.conf $(GNUPGHOME)/.data/config
	cd $(GNUPGHOME) && \
		source .data/config && \
		$(GPGCMD) --quick-generate-key "$${GPG_USER_ID}" "$${MASTER_ALGO}" cert "$${MASTER_VALIDITY}"

$(GNUPGHOME)/.data/keyid-master.txt: $(GNUPGHOME)/private-keys-v1.d
	cd $(GNUPGHOME) && \
		$(GPGCMD) --list-secret-keys | awk '/^sec/ {gsub("(rsa|elg|dsa|ecdh|ecdsa|eddsa)*[0-9]+R?/", "", $$2); print $$2}' > .data/keyid-master.txt

$(GNUPGHOME)/.data/keyfp-master.txt: $(GNUPGHOME)/.data/keyid-master.txt
	cd $(GNUPGHOME) && \
		$(GPGCMD) --list-secret-keys | awk -F= '/Key fingerprint/ {gsub(" ", "", $$2); print $$2}' > .data/keyfp-master.txt

$(GNUPGHOME)/.data/key-master.asc: $(GNUPGHOME)/.data/keyfp-master.txt
	cd $(GNUPGHOME) \
		&& $(GPGCMD) --armor --output .data/key-master.asc --export-secret-keys $(shell cat $(GNUPGHOME)/.data/keyid-master.txt)

$(GNUPGHOME)/.data/paperkey-master.txt: $(GNUPGHOME)/.data/key-master.asc
	cd $(GNUPGHOME) \
		&& $(GPGCMD) --export-secret-keys | paperkey -o .data/paperkey-master.txt

###
# subkey
###
$(GNUPGHOME)/.data/subkeyid-$(KEYSET).txt: $(GNUPGHOME)/gpg.conf $(GNUPGHOME)/.data/config
	cd $(GNUPGHOME) \
		&& source .data/config \
		&& $(GPGCMD) --quick-add-key "$(shell cat $(GNUPGHOME)/.data/keyfp-master.txt)" "$${SUBKEY_ALGO}" "$(KEYSET)" "$${SUBKEY_VALIDITY}"
	cd $(GNUPGHOME)\
		&& $(GPGCMD) --list-secret-keys | awk '/^ssb.*\[$(KEYTAG)\]/ {gsub("(rsa|elg|dsa|ecdh|ecdsa|eddsa|ed)*[0-9]+R?/", "", $$2); print $$2}' | head -n1 > .data/subkeyid-$(KEYSET).txt


$(GNUPGHOME)/.data/subkey-$(KEYSET).asc: $(GNUPGHOME)/.data/subkeyid-$(KEYSET).txt
	cd $(GNUPGHOME) \
		&& $(GPGCMD) --armor --output .data/subkey-$(KEYSET).asc --export-secret-subkeys "$(shell cat $(GNUPGHOME)/.data/subkeyid-$(KEYSET).txt)"

$(GNUPGHOME)/.data/paperkey-subkey-$(KEYSET).txt: $(GNUPGHOME)/.data/subkey-$(KEYSET).asc
	cd $(GNUPGHOME) \
		&& $(GPGCMD) --export-secret-subkeys "$(shell cat $(GNUPGHOME)/.data/subkeyid-$(KEYSET).txt)" | pakerkey -o .data/paperkey-subkey-$(KEYSET).txt

$(GNUPGHOME)/.data/id_rsa.pub: $(GNUPGHOME)/.data/paperkey-subkey-$(KEYSET).txt
	cd $(GNUPGHOME) \
		&& source .data/config \
		&& [ "$(KEYSET)" = "auth" ] \
		&& $(GPGCMD) --export-ssh-key "${GPG_EMAIL}" --output .data/id_rsa.pub

###
# perform smartcard actions
###
.PHONY: sckey
sckey: $(GNUPGHOME)/.data/keyid-master.txt
	@echo "==================================================================================="
	@echo
	@echo "Unfortunately GnuPG 2.1 doesn't yet support automation of the SmartCard functions"
	@echo "so you'll have to carry out the following steps manually."
	@echo
	@echo "To create signing and and authentication keys directly on the SmartCard you'll"
	@echo "need the following commands:"
	@echo
	@echo "  1. `toggle` to enter admin mode"
	@echo
	@echo "  2. `key 1` to select the encryption subkey designated by 'usage: E'"
	@echo "  3. `keytocard` to move the selected encryption key to the card.  Follow the"
	@echo "     instructions to complete this step.  When done you should see 'ssb>' next to"
	@echo "     the key indicating you have a stub locally"
	@echo
	@echo "  4. `addcardkey` and follow the instructions to generate a signing key on the card"
	@echo "  5. Repeat previous step to create an auth subkey"
	@echo
	@echo "  6. `quit` to leave the edit-key mode."
	@echo
	@echo "If you want to prepare a second SmartCard with the same encryption key you'll"
	@echo "have to `make import-encr sckey` to re-import the encryption key and put it on"
	@echo "the second SmartCard.  If you're running the `default` target this is done"
	@echo "automatically for you after you exit this session."
	@echo
	@echo "==================================================================================="
	cd $(GNUPGHOME) && \
		$(GPGCMD) --edit-key "$(shell cat $(GNUPGHOME)/.data/keyid-master.txt)"

###
# import encryption key following moving it to a SmartCard
###
.PHONY: import-encr
import-encr:
	cd $(GNUPGHOME) && \
		$(GPGCMD) --import .data/subkey-encr.asc

###
# remove master key
###
.PHONY: remove-master
remove-master:
	cd $(GNUPGHOME) && \
		$(GPGCMD) --export-secret-subkeys --armor > .data/subkey-shadows.asc && \
		$(GPGCMD) --delete-secret-keys $(shell cat $(GNUPGHOME)/.data/keyid-master.txt) && \
		$(GPGCMD) --import .data/subkey-shadows.asc

###
# import secret subkeys & link to smartcard
###
.PHONY: import-ssb
import-ssb:
	$(GPGBIN) --import $(SUBKEYS)
	$(GPGBIN) --card-status

###
# test
###
.PHONY: test
test:
	cd $(GNUPGHOME) && \
		source .data/config && \
		echo '🔐 If you can read this the encryption and decryption have worked! 🎉' | \
		$(GPGCMD) --encrypt --sign -a -r $${GPG_EMAIL} | \
		$(GPGCMD) --decrypt

###
# Common, config and other phonies
###
$(GNUPGHOME)/.data/.keep:
		mkdir -p "$(GNUPGHOME)/.data"
		chmod 700 "$(GNUPGHOME)"
		chmod 700 "$(GNUPGHOME)/.data"
		touch "$(GNUPGHOME)/.data/.keep"

$(GNUPGHOME)/.data/gpg-version: $(GNUPGHOME)/.data/.keep
	@if [ $(GPG_VERSION_MAJOR) -ge 2 ] && [ $(GPG_VERSION_MINOR) -ge 1 ]; then \
		echo "Found GnuPG $(GPG_VERSION_MAJOR).$(GPG_VERSION_MINOR)"; \
		$(GPGBIN) --version > $(GNUPGHOME)/.data/gpg-version 2>&1; \
	else \
		echo "GnuPG >= 2.1 is required, found GnuPG $(GPG_VERSION_MAJOR).$(GPG_VERSION_MINOR)"; \
		exit 1; \
	fi

$(GNUPGHOME)/gpg.conf: $(GNUPGHOME)/.data/gpg-version
	cp gpg.conf-sample $(GNUPGHOME)/gpg.conf

$(GNUPGHOME)/.data/config: $(GNUPGHOME)/.data/gpg-version
	cp config-sample $(GNUPGHOME)/.data/config
	$(EDITOR) $(GNUPGHOME)/.data/config
