# GPG on Yubikeys

When using physical tokens we want to have a different signing key on each
token, however have a common encryption/decription key on both tokens.  The
reason for having a common encryption/decription key on both tokens is that we
must make it easy for others to send us encrypted messages and not require
them to have any knoweldge of our GPG setup.

# Considerations

## GPG max key size

GPG has a hard max key size of 4096bit.  Apparently the brew version has upped
this to 8192bit.  You can try that if you desire.

## gpg-agent socket path length limit

As of GnuPG 2.1 the key handling logic has been entirely moved out of the old
`gpg` binary and into `gpg-agent`.  As a result `gpg-agent` will be invoked
automatically as needed, and therefore the `gpg-agent` socket will always be
used for communication between the `gpg` command line interface and the
running `gpg-agent`.  Unfortunately sockets on Unix systems have a hard limit
of 108 characters in their path, including macOS.  This is not a limitation of
GnuPG but rather of the underlying OS, and `gpg` may fail slightly cryptically
if the path is longer than 108 characters.
