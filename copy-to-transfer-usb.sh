#!/usr/bin/env bash

set -x

GPGHOME="${1%\/}"
POOL="$2"

usage() {
	echo "Usage: $(basename $0) GPGHOME ZFS_POOL"
	echo "  GPGHOME      Path to the GPG working directory"
	echo "  ZFS_POOL     The pool name to work with"
	exit 1
}
[ -n "$GPGHOME" ] || usage
[ -n "$POOL" ] || usage

set -eu

GPGDIR=$(basename ${GPGHOME})

sudo zpool import -R ${HOME}/zpools ${POOL}
sudo zpool scrub ${POOL}

sudo chown -R ${USER}: ${HOME}/zpools/${POOL}
rsync -ca --progress --stats --exclude="S.gpg-agent*" --exclude="S.scdaemon" ${GPGHOME}/DATA-transferred ${HOME}/zpools/${POOL}/${GPGDIR}
rsync -ca --delete-before --progress --stats ${HOME}/gpg-smartcard-automation ${HOME}/zpools/${POOL}/

sudo zpool scrub ${POOL}
sudo zpool export ${POOL}
