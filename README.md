# Automate GPG hierarchy creation, optionally on Yubikey(s) and/or SmartCard(s)

## Quick start

These steps will prepare two SmartCards with secret subkeys, paperkey backups
that can be printed, and a revocation certificate in case the master key is
lost.

1. Prepare some USB drives for storing and transferring keys:

      1. Two USB thumb drives for storing your master key.  These should
         ideally only be used on an airgapped device.
      2. One USB thumb drive for transferring public keys and shadow keys to
         your regular workstation.

1. Generate keys - this step is ideally run on an air gapped device

       make default

    The above command will:

      1. Set up a local soft master key
      2. Generate a soft encryption key locally
      3. Start the gpg interactive interface to:
        a) create signing and auth keys directly on the card
        b) load the soft encryption key onto the card
        c) extract the SSH public key from the card
      4. Re-import the prevoiusly generated encryption key locally
      5. Repeat step 3 to set up a second smartcard (optionally)
      6. Test the encryption, signing, decryption & validation

2. Copy following files for use on main device

       $(GNUPGHOME)/.data/id_rsa.pub
       $(GNUPGHOME)/.data/subkeys.asc

3. Optionally store your revocation certificate somewhere safe and separate to
   your master key.

       $(GNUPGHOME)/openpgp-revocs.d

4. On your regular workstation:

      1. Plug in a smartcard
      2. Plug in the USB drive used to transfer between airgapped and
         workstation.
      3. Import the subkey shadows into your GPG keychain, and let GPG
         recognize the shadow counterparts are on the smartcard.

          For the first device:

             SUBKEYS=/path/to/subkeys.asc make import-ssb

          Then for the second device you only need to link the keys by calling:

             gpg --card-status

## Usage

Use the built-in help for additional commands and usage

```
$ make help

Usage: [GPGHOME=/path/to/gnupghome] make [TARGET]
Where:
  GPGHOME          the path to a folder for new keyrings, or containing existing keyrings

Targets:
  default          create a soft master key and encryption subkey, then
                   initialise two smartcards with signing and auth subkeys
                   and the soft encryption key.

  softkeys         (default) create a full set of keys: master, soft signing
                   subkey, soft encryption subkey, soft auth key.

  master           create a master key used to sign subkeys.
  signing          a soft subkey used for signing only
  encryption       a soft subkey used for encryption only
  auth             a soft subkey used for authentication only

  show             Display secret key information for temporary working path,
                   and card status.

  remove-master    Backup and remove the private master key from the working keychain

  import-ssb FILE  Import secret subkeys in FILE and link to SmartCard

  test             Perform a sign and encrypt, and a decrypt and verify to confirm
                   all is functioning as expected.

  reset-yubikey    Reset the GPG applet on a yubikey. WARNING: this will
                   irrevicoable wipe your smartcard.

  clean            Clean up previously created GNUPGHOME paths

Requirements:
  Only GPG >= 2.1 is supported.
```

## Requirements

1. GnuPG >= 2.1
2. GNU Make


### Optional

- Air gapped device.  Either a system that is not online, or make use of
  a live system image, with connectivity disabled.
- One or two SmartCards, such as Yubikeys
- At least two USB thumb drives to keep your master key safe.  You may want to
  consider using SLC sticks, and/or using [ZFSonLinux](http://zfsonlinux.org/)
  / [O3X](https://openzfsonosx.org/) to keep the keys safe.  More details on
  some options below.
- A third USB thumb drive to transfer subkeys shadows if using a SmartCard, or
  private subkeys if not using a smartcard, and public keys to your regular
  device.

## Overview

There are numerous well written guides that describe how to manually generate
a GPG key set.  The aim of this work is to automate that so you can generate
and import such a key set with minimal effort.

The goal is to have a structure as follows for your day to day use such that
the master secret key is only stored on cold storage and all the private sub
keys are either soft keys in your regular ~/.gnupg keyring, or are stored on
a Yubikey or other PGP/GPG SmartCard.

    sec#  rsa4096 2017-06-26 [C] [expires: 2022-06-25]
          D49147668E74D68C108A83DB53E708995F9835CD
    uid           [ultimate] Real Name (https://keybase.io/userid) <email@addr.ess>
    ssb>  rsa2048 2017-06-26 [E] [expires: 2019-06-26]
    ssb>  rsa4096 2017-06-26 [S] [expires: 2019-06-26]
    ssb>  rsa4096 2017-06-26 [A] [expires: 2019-06-26]

In the above example we can make the following observations:

- the `#` in `sec#` indicates the private key part of the master key is not
  available locally
- the `[C]` indicates the master key is only capable of certification
- signing (`[S]`), encryption (`[E]`) and authentication (`[A]`) are all
  achieved by the individual subkeys
- the `>` in `ssb>` indicates the private key for each subkey is stored on
  a SmartCard or Yubikey.
- the encryption key is 2048 bit so that it can be shared between multiple
  cards, among which the lowest common support is 2048 bit keys
- the signing and authentication keys are 4096 bit as they're generated on the
  card at the maximum supported bits for that specific card

## Master key

The master key is a soft key only capable of certification and should not be
stored on a device used daily.  It's a good idea to keep this safe on an
encrypted USB device, and even better to have a print out of it, as is
prepared by paperkey.

The generate master key backups are stored at:

  - $(GNUPGHOME)/.data/key-master.asc
  - $(GNUPGHOME)/.data/paperkey-master.txt

## Signing, authentication and encryption sub keys

When using physical tokens we want to have a different signing and
authentication keys on each token so that in the event one SmartCard is lost
we only need to revoke that single key set of that SmartCard.

However for the encryption key it's most convenient to have the same subkey
used on both tokens as that makes it easy for others to send us encrypted
messages and not require them to have any knoweldge of our GPG key structure.

For these reasons we generate the encryption key as a soft key that is
transferred to the SmartCard(s), while we generate the signing and
authentication keys directly on the cards.

If you don't have a SmartCard then you can generate all the keys as soft keys
using the following command:

    make softkeys

Storing and keeping the soft keys safe is essentially the same as when using
a SmartCard.

## Cold storage of the master key and revocation certificates

Ideally all your key material will be generated on an air gapped device.  If
you use an ephemeral system for this, such as Tails, you'll need to keep your
master key and revocation certificates on a couple of USB sticks.

You may want to use SLC (Single Layer Cell) USB sticks as they should be more
resilient.

You should probably print out the paperkey representations of all private key
material.

If you want to have interoperability between macOS and linux you can use
[ZFSonLinux](http://zfsonlinux.org/) / [O3X](https://openzfsonosx.org/).  With
that you can also create your pool with multiple copies of data so that bitrot
is less likely to break your keys.

If you want encryption and interoperability you can layer EncFS on top of ZFS.

### Creating ZFS pools

This section isn't comprehensive as there's enough documentation online,
however here's a quick start to creating a pool with multipe data copies on
a single stick:

1. Determine the device for your USB stick

       diskutil list

    Look for the device that corresponds to the characteristics of your stick
    and take node of the `/dev/diskX` title.

2. Create the new zpool.  This is a destructive operation on the USB stick, so
   be sure you know what you're doing.

       sudo zpool create -f -o ashift=12 -O copies=3 -O normalization=formD gpg-backup-1 /dev/diskX

    This will create a volume with 3 copies of your data.  To detect bitrot
    you'll need to perform scrubs of the disk as ZFS doesn't do this during
    normal operation.  See
    [ZFSonLinux issue 1256](https://github.com/zfsonlinux/zfs/issues/1256)
    for more details.

## To do

- Manage key expiry extention.  As of GPG 2.1 only master key expiry can be
  easily manipulated with --quick-set-expire.
- Add tests to validate all resulting artefacts are as expected, for example
  the exported ASCII armored private key and subkeys are well structured and
  encrypted, and the SSH public key is exported correctly.
- When GnuPG supports automation of card key generation this will need to be
  implemented.

## Known issues

### GPG max key size

GPG has a hard max key size of 4096bit.  Apparently the brew version has upped
this to 8192bit.  You can try that if you desire, however keep in mind that
most SmartCards only support 2048bit, while a few now support 4096bit.

### gpg-agent socket path length limit

As of GnuPG 2.1 the key handling logic has been entirely moved out of the old
`gpg` binary and into `gpg-agent`.  As a result `gpg-agent` will be invoked
automatically as needed, and therefore the `gpg-agent` socket will always be
used for communication between the `gpg` command line interface and the
running `gpg-agent`.  Unfortunately sockets on Unix systems have a hard limit
of 108 characters in their path, including macOS.  This is not a limitation of
GnuPG but rather of the underlying OS, and `gpg` may fail slightly cryptically
if the path is longer than 108 characters.
