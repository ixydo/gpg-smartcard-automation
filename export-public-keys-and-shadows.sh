#!/usr/bin/env bash

set -eE
set -x

PRIMARY_KEY=$(cat DATA-transferred/keyid-master.txt)

for gnupg in gnupg-0{4,7}*; do
  gpgconf --kill gpg-agent scdaemon
  export GNUPGHOME=$(readlink -f "$gnupg")
  CARD_ID=${gnupg/gnupg-/}

  # Export public keys
  gpg --export --export-options export-minimal --armor \
    "$PRIMARY_KEY" \
    > "DATA-transferred/public-$CARD_ID-$(date -I).asc"

  # Export subkey shadows
  gpg --export-secret-subkeys --export-options export-minimal --armor \
    > "DATA-transferred/subkey-shadows-$CARD_ID-$(date -I).asc"
done

gpgconf --kill gpg-agent scdaemon
unset GNUPGHOME
