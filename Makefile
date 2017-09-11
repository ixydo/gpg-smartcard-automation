# vim:set ts=2 sw=2 sts=2 noexpandtab:

.PHONY: help
help:
	@echo "Usage: [GPGHOME=/path/to/gnupghome] (g)make [TARGET]"
	@echo "Where:"
	@echo "  GPGHOME          the path to a folder for new keyrings, or containing existing keyrings"
	@echo "                   will be created if it doesn't exist, and will contain subfolders for"
	@echo "                   each smartcard/yubikey detected"
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
	@echo "  import-secrets   delete the master key and subkeys, then re-import the master key"
	@echo "                   and the encryption subkey"
	@echo
	@echo "  show             Display secret key information for temporary working path,"
	@echo "                   and card status."
	@echo
	@echo "  remove-master    Backup and remove the private master key from the working keychain"
	@echo
	@echo "  import-ssb       Import secret subkeys in FILE and link to SmartCard, requires"
	@echo "                   that you set SHADOWS=/path/to/DATA-transfered/subkey-shadows.asc"
	@echo
	@echo "  test             Perform a sign and encrypt, and a decrypt and verify to confirm"
	@echo "                   all is functioning as expected."
	@echo
	@echo "  reset-yubikey    Reset the GPG applet on a yubikey. WARNING: this will"
	@echo "                   irrevicoable wipe your smartcard."
	@echo
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
GPGBIN ?= gpg
CARDNO := $(shell $(GPGBIN) --no-keyring --card-status 2>/dev/null | awk -F: '/^Serial/ {gsub("[    ]+", "", $$2); print $$2}')

ifeq ($(GPGHOME),GPGHOME)
ifeq ($(CARDNO),)
	GNUPGHOME := $(shell /bin/date '+%F_%H%M')/gnupg
else
	GNUPGHOME := $(shell /bin/date '+%F_%H%M')/gnupg-$(CARDNO)
endif
else
ifeq ($(CARDNO),)
	GNUPGHOME := $(GPGHOME)/gnupg
else
	GNUPGHOME := $(GPGHOME)/gnupg-$(CARDNO)
endif
endif

GPGCMD ?= $(GPGBIN) --no-default-keyring --homedir $(GNUPGHOME)
GPG_VERSION_MAJOR = $(shell $(GPGCMD) --version 2>&1 | awk '/^gpg.*[0-9\.]+$$/ {print $$3}' | grep -Eo '^[0-9]')
GPG_VERSION_MINOR = $(shell $(GPGCMD) --version 2>&1 | awk '/^gpg.*[0-9\.]+$$/ {print $$3}' | sed -e 's/^[0-9]\.//' -e 's/\.[0-9]*$$//')

###
# Public goals
###
.PHONY: default
default: master sckey $(GPGHOME)/DATA-transferred/subkey-shadows.asc id_rsa.pub test
	@echo "🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 🔑 "
	@echo "Your keys have been generated."
	@echo
	@echo "To prepare another smartcard/yubikey with subkeys off this master key do the following:"
	@echo
	@echo "  1. '$(MAKE) import-secrets sckey'"
	@echo "  2. Follow the below instructions to backup up all public and private components"
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
	@echo " - $(GPGHOME)/DATA-airgapped/paperkey-master.txt"
	@echo " - $(GPGHOME)/DATA-airgapped/paperkey-subkey-*.txt"
	@echo
	@echo "⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ ⏳ "
	@echo "Your keys, both master and subkeys, are set to expire.  To extend their"
	@echo "validity you'll need to use the master key."
	@echo
	@echo "🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 🔐 "
	@echo "Finally, you'll want to transfer the following files to your regular"
	@echo "device and import the subkeys into your regular ~/.gnupg keychain."
	@echo " - $(GPGHOME)/DATA-transferred/subkey-shadows.asc"
	@echo " - $(GPGHOME)/DATA-transferred/id_rsa.pub"
	@echo

.PHONY: softkeys
softkeys: master $(GPGHOME)/DATA-airgapped/paperkey-subkey-sign.txt $(GPGHOME)/DATA-airgapped/paperkey-subkey-auth.txt
	$(MAKE) signing
	$(MAKE) encryption
	$(MAKE) auth

.PHONY: master
master: $(GPGHOME)/DATA-airgapped/paperkey-master.txt
	$(MAKE) encryption

.PHONY: signing
signing: $(GPGHOME)/DATA-airgapped/subkey-sign.asc

.PHONY: encryption
encryption: $(GPGHOME)/DATA-airgapped/subkey-encr.asc $(GPGHOME)/DATA-airgapped/paperkey-subkey-encr.txt

.PHONY: auth
auth: id_rsa.pub

# reset
reset-yubikey:
	@echo "Are you sure you want to reset the yubikey GPG applet?  This is a destructive"
	@echo "action and not reversible."
	@bash -c "read -r -p \"Type 'reset-yubikey' if you're sure you want to continue: \" ANS; \
	if [ \$$ANS = 'reset-yubikey' ]; then \
		gpg-connect-agent -r yubikey-reset.txt; \
	else \
		echo 'You entered '\$$ANS', so the card was NOT reset.'; \
	fi"

# clean
.PHONY: clean
clean:
	@if [ -d "$(GPGHOME)" ]; then \
		echo "Will remove following path: $(GPGHOME)"; \
		echo "Continue (y/N)?"; \
		read -r REPLY; \
		if [ $${REPLY} = 'y' ]; then \
			rm -rf "$(GPGHOME)"; \
			echo "Done."; \
		else \
			echo "Aborted."; \
		fi \
	fi
	@if [ $$(ls -1d $$(/bin/date '+%F_')* 2>/dev/null | wc -l) -eq 0 ]; then \
		echo "No auto-generated folders to clean."; \
	else \
		@echo "Will remove following paths:"; \
		RMPATHS=$$(/bin/date '+%F_%H'); \
		ls -1d $${RMPATHS}*; \
		echo "Continue (y/N)?" \
		read -r REPLY; \
		if [ $${REPLY} = 'y' ]; then \
			rm -rf "$${RMPATHS}*"; \
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
$(GNUPGHOME)/private-keys-v1.d: $(GNUPGHOME)/gpg.conf $(GPGHOME)/DATA-airgapped/config
	cd $(GNUPGHOME) && \
		. $(GPGHOME)/DATA-airgapped/config && \
		$(GPGCMD) --quick-generate-key "$${GPG_USER_ID}" "$${MASTER_ALGO}" cert "$${MASTER_VALIDITY}" || :

$(GPGHOME)/DATA-transferred/keyid-master.txt: $(GNUPGHOME)/private-keys-v1.d
	cd $(GNUPGHOME) && \
		$(GPGCMD) --list-secret-keys | awk '/^sec/ {gsub("(rsa|elg|dsa|ecdh|ecdsa|eddsa)*[0-9]+R?/", "", $$2); print $$2}' > $(GPGHOME)/DATA-transferred/keyid-master.txt

$(GPGHOME)/DATA-transferred/keyfp-master.txt: $(GPGHOME)/DATA-transferred/keyid-master.txt
	cd $(GNUPGHOME) && \
		$(GPGCMD) --list-secret-keys | awk -F= '/Key fingerprint/ {gsub(" ", "", $$2); print $$2}' > $(GPGHOME)/DATA-transferred/keyfp-master.txt

$(GPGHOME)/DATA-airgapped/key-master.asc: $(GPGHOME)/DATA-transferred/keyfp-master.txt
	cd $(GNUPGHOME) \
		&& $(GPGCMD) --armor --output $(GPGHOME)/DATA-airgapped/key-master.asc --export-secret-keys $(shell head -n1 $(GPGHOME)/DATA-transferred/keyid-master.txt) \
		&& $(GPGCMD) --armor --output $(GPGHOME)/DATA-transferred/key-master.pub --export $(shell head -n1 $(GPGHOME)/DATA-transferred/keyid-master.txt)

$(GPGHOME)/DATA-airgapped/paperkey-master.txt: $(GPGHOME)/DATA-airgapped/key-master.asc
	cd $(GNUPGHOME) \
		&& $(GPGCMD) --export-secret-keys | paperkey -o $(GPGHOME)/DATA-airgapped/paperkey-master.txt

###
# subkey
###
$(GPGHOME)/DATA-transferred/subkeyid-$(KEYSET).txt: $(GNUPGHOME)/gpg.conf $(GPGHOME)/DATA-airgapped/config
	cd $(GNUPGHOME) \
		&& . $(GPGHOME)/DATA-airgapped/config \
		&& $(GPGCMD) --quick-add-key "$(shell head -n1 $(GPGHOME)/DATA-transferred/keyfp-master.txt)" "$${SUBKEY_ALGO}" "$(KEYSET)" "$${SUBKEY_VALIDITY}"
	cd $(GNUPGHOME)\
		&& $(GPGCMD) --list-secret-keys | awk '/^ssb.*\[$(KEYTAG)\]/ {gsub("(rsa|elg|dsa|ecdh|ecdsa|eddsa|ed)*[0-9]+R?/", "", $$2); print $$2}' | head -n1 > $(GPGHOME)/DATA-transferred/subkeyid-$(KEYSET).txt


$(GPGHOME)/DATA-airgapped/subkey-$(KEYSET).asc: $(GPGHOME)/DATA-transferred/subkeyid-$(KEYSET).txt
	cd $(GNUPGHOME) \
		&& $(GPGCMD) --armor --output $(GPGHOME)/DATA-airgapped/subkey-$(KEYSET).asc --export-secret-subkeys "$(shell head -n1 $(GPGHOME)/DATA-transferred/subkeyid-$(KEYSET).txt)" \
		&& $(GPGCMD) --armor --output $(GPGHOME)/DATA-transferred/subkey-$(KEYSET).pub --export "$(shell head -n1 $(GPGHOME)/DATA-transferred/subkeyid-$(KEYSET).txt)"

$(GPGHOME)/DATA-airgapped/paperkey-subkey-$(KEYSET).txt: $(GPGHOME)/DATA-airgapped/subkey-$(KEYSET).asc
	cd $(GNUPGHOME) \
		&& $(GPGCMD) --export-secret-subkeys "$(shell head -n1 $(GPGHOME)/DATA-transferred/subkeyid-$(KEYSET).txt)" | paperkey -o $(GPGHOME)/DATA-airgapped/paperkey-subkey-$(KEYSET).txt

.PHONY: id_rsa.pub
id_rsa.pub:
	cd $(GNUPGHOME) && \
		$(GPGCMD) --list-secret-keys | awk '/\[A\]/ {gsub(".*/", "", $$2); print $$2}' | while read -r SSH_KEY; do \
			if [ ! -r $(GPGHOME)/DATA-transferred/id_rsa-$${SSH_KEY}.pub ]; then \
				$(GPGCMD) --export-ssh-key "$${SSH_KEY}" > $(GPGHOME)/DATA-transferred/id_rsa-$${SSH_KEY}.pub; \
			fi; \
		done 

###
# perform smartcard actions
###
.PHONY: sckey
sckey: cardedit id_rsa.pub $(GPGHOME)/DATA-transferred/subkey-shadows.asc

.PHONY: cardedit
cardedit: $(GPGHOME)/DATA-transferred/keyid-master.txt
	@echo "==================================================================================="
	@echo
	@echo "Unfortunately GnuPG 2.1 doesn't yet support automation of the SmartCard functions"
	@echo "so you'll have to carry out the following steps manually."
	@echo
	@echo "To create signing and and authentication keys directly on the SmartCard you'll"
	@echo "need the following commands:"
	@echo
	@echo "  1. 'toggle' to enter admin mode"
	@echo
	@echo "  2. 'key 1' to select the encryption subkey designated by 'usage: E'. Make sure"
	@echo "     select the correct subkey, it may be 'key 3' for example."
	@echo "  3. 'keytocard' to move the selected encryption key to the card.  Follow the"
	@echo "     instructions to complete this step.  When done you should see 'ssb>' next to"
	@echo "     the key indicating you have a stub locally"
	@echo
	@echo "  4. 'addcardkey' and follow the instructions to generate a signing key on the card"
	@echo "  5. Repeat previous step to create an auth subkey"
	@echo
	@echo "  6. 'quit' to leave the edit-key mode."
	@echo
	@echo "If you want to prepare a second SmartCard with the same encryption key you'll"
	@echo "have to repeat this step with '$(MAKE) import-secrets sckey' to re-import the encryption"
	@echo "key and put it on the second SmartCard."
	@echo
	@echo "==================================================================================="
	cd $(GNUPGHOME) && \
		$(GPGCMD) --edit-key "$(shell head -n1 $(GPGHOME)/DATA-transferred/keyid-master.txt)" || :
		# There seems to be a bug in at least GPG-2.1.23 that results in occasional
		# non-zero exit codes when finishing the --edit-key interaction, so we explicitly
		# return true at this point.

###
# import encryption key following moving it to a SmartCard
###
.PHONY: import-secrets
import-secrets: $(GNUPGHOME)/gpg.conf
	killall gpg-agent scdaemon 2>/dev/null || :
	cd $(GNUPGHOME) && \
		$(GPGCMD) --batch --delete-secret-and-public-keys "$(shell head -n1 $(GPGHOME)/DATA-transferred/keyid-master.txt)" || :; \
		$(GPGCMD) --import $(GPGHOME)/DATA-airgapped/key-master.asc && \
		$(GPGCMD) --import $(GPGHOME)/DATA-airgapped/subkey-encr.asc

###
# remove master key
###
.PHONY: remove-master
remove-master: $(GPGHOME)/DATA-transferred/subkey-shadows.asc
	cd $(GNUPGHOME) && \
		$(GPGCMD) --delete-secret-keys $(shell head -n1 $(GPGHOME)/DATA-transferred/keyid-master.txt) && \
		$(GPGCMD) --import $(GPGHOME)/DATA-transferred/subkey-shadows.asc

###
# import secret subkeys & link to smartcard
###

.PHONY: $(GPGHOME)/DATA-transferred/subkey-shadows.asc
$(GPGHOME)/DATA-transferred/subkey-shadows.asc:
	cd $(GNUPGHOME) && \
		CARDNO=$(shell $(GPGCMD) --card-status | awk -F: '/^Serial/ {gsub("[    ]+", "", $$2); print $$2}') && \
		$(GPGCMD) --export-secret-subkeys --armor > $(GPGHOME)/DATA-transferred/subkey-shadows-$${CARDNO}.asc
		$(GPGCMD) --export --armor > $(GPGHOME)/DATA-transferred/subkey-shadows-$${CARDNO}.pub

.PHONY: import-ssb
import-ssb:
	@if [ -z "$(SHADOWS)" ]; then \
		echo "ERROR: You must set SHADOWS=/path/to/DATA-transfered/subkey-shadows.asc for this to work."; \
		exit 1; \
	fi
	killall gpg-agent scdaemon 2>/dev/null || :
	$(GPGBIN) --import $(SHADOWS)
	$(GPGBIN) --card-status

###
# test
###
.PHONY: test
test:
	killall gpg-agent scdaemon 2>/dev/null || :
	@echo '%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%'
	@echo 'Testing that we can encrypt & sign, then decrypt and validate a message.'
	@cd $(GNUPGHOME) && \
		{ echo '🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐🔐'; \
	    echo 'If you can read this the encryption and decryption have worked!'; \
		  echo '🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉'; \
		}	| \
		$(GPGCMD) --encrypt --sign -a -r $(shell head -n1 $(GPGHOME)/DATA-transferred/keyfp-master.txt) | \
		$(GPGCMD) --decrypt || echo 'FAILED.  Check that you have a working pinentry program configured'
	@echo '%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%'

###
# Common, config and other phonies
###
$(GPGHOME)/DATA-transferred/.keep:
	mkdir -m 0700 -p $(GPGHOME)/DATA-transferred
	touch "$(GPGHOME)/DATA-transferred/.keep"

$(GPGHOME)/DATA-airgapped/.keep: $(GPGHOME)/DATA-transferred/.keep
	mkdir -m 0700 -p $(GPGHOME)/DATA-airgapped
	touch "$(GPGHOME)/DATA-airgapped/.keep"

$(GNUPGHOME):
	killall gpg-agent scdaemon 2>/dev/null || :
	mkdir -m 0700 -p $(GNUPGHOME)

$(GPGHOME)/DATA-airgapped/gpg-version: $(GNUPGHOME) $(GPGHOME)/DATA-airgapped/.keep
	@if [ $(GPG_VERSION_MAJOR) -ge 2 ] && [ $(GPG_VERSION_MINOR) -ge 1 ]; then \
		echo "Found GnuPG $(GPG_VERSION_MAJOR).$(GPG_VERSION_MINOR)"; \
		$(GPGBIN) --version > $(GPGHOME)/DATA-airgapped/gpg-version 2>&1; \
	else \
		echo "GnuPG >= 2.1 is required, found GnuPG $(GPG_VERSION_MAJOR).$(GPG_VERSION_MINOR)"; \
		exit 1; \
	fi

$(GNUPGHOME)/gpg-agent.conf:
	@if [ $(shell uname) == 'FreeBSD' ] && [ ! -r $(GNUPGHOME)/gpg-agent.conf ]; then \
		for PINENTRY in pinentry-gnome3 pinentry-gtk; do \
			if [ -x /usr/local/bin/$${PINENTRY} ]; then \
				echo "pinentry-program /usr/local/bin/$${PINENTRY}" > $(GNUPGHOME)/gpg-agent.conf; \
				break; \
			elif [ -x /usr/bin/$${PINENTRY} ]; then \
				echo "pinentry-program /usr/local/bin/$${PINENTRY}" > $(GNUPGHOME)/gpg-agent.conf; \
				break; \
			fi; \
		done; \
		echo "default-cache-ttl 3600" >> $(GNUPGHOME)/gpg-agent.conf; \
		echo "enable-extended-key-format" >> $(GNUPGHOME)/gpg-agent.conf; \
	fi

$(GNUPGHOME)/gpg.conf: $(GPGHOME)/DATA-airgapped/gpg-version $(GNUPGHOME)/gpg-agent.conf
	cp gpg.conf-sample $(GNUPGHOME)/gpg.conf

$(GPGHOME)/DATA-airgapped/config: $(GPGHOME)/DATA-airgapped/gpg-version
	if [ ! -f $(GPGHOME)/DATA-airgapped/config ]; then \
	 	cp config-sample $(GPGHOME)/DATA-airgapped/config; \
		$(EDITOR) $(GPGHOME)/DATA-airgapped/config; \
	fi
