#!/usr/bin/env bash

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

set -eux

[ -r ${HOME}/encfs ] || mkdir ${HOME}/encfs

sudo zpool import -R ${HOME}/zpools $POOL
sudo zpool scrub $POOL
sudo encfs --public ${HOME}/zpools/$POOL ${HOME}/encfs
sudo chown -R ${USER}: ${HOME}/encfs
rsync -ca --progress --stats --exclude="S.gpg-agent*" --exclude="S.scdaemon" $GPGHOME ${HOME}/encfs/
rsync -ca --delete-before --progress --stats ${HOME}/gpg-smartcard-automation ~/zpools/${POOL}/
sudo umount ${HOME}/encfs
sudo zpool scrub $POOL
sudo zpool export ${POOL}
