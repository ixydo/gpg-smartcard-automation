# Automate GPG keyset creation, optionally on Yubikey(s) and/or SmartCard(s)

TL;DR: jump to the [Instructions for creating an airgapped key set with two
yubikeys](#scenario1)

## Overview

There are numerous well written guides that describe how to manually generate
a GPG key set, both for soft keys and for Yubikeys or other PGP/GPG
SmartCards.  The aim of this work is to automate the GPG commands so you can
generate and create your key set without having to become a GPG veteran.

There are a couple of scenarios currently supported:

1. An offline soft master key, and subkeys stored on one or more smartcards or
   yubikeys.
2. An offline soft master key, and soft subkeys that can be imported into your
   main devices.
3. An offline soft master key, and several sets of soft subkeys, with a common
   encryption key to be used across devices.

You can, of course, choose not to keep your master key offline or airgapped.

### What to expect

The goal is to have a structure as follows for your day to day use.  The
master secret key is:

 - generated on an airgapped device 
 - only stored in cold storage
 - only capable of certifying subkeys
 
All the private sub keys are either soft keys in your regular ~/.gnupg
keyring, or are stored on a Yubikey or other PGP/GPG smartcard.

    sec#  rsa4096 2017-06-26 [C] [expires: 2022-06-25]
          D49147668E74D68C108A83DB53E708995F9835CD
    uid           [ultimate] Real Name (https://keybase.io/userid) <email@addr.ess>
    ssb>  rsa2048 2017-06-26 [E] [expires: 2019-06-26]
    ssb>  rsa4096 2017-06-26 [S] [expires: 2019-06-26]
    ssb>  rsa4096 2017-06-26 [A] [expires: 2019-06-26]

In the above example we can make the following observations:

- the `#` in `sec#` indicates the private key part of the master key is not
  available locally
- the `>` in `ssb>` indicates the private key for each subkey is stored on
  a PGP/GPG SmartCard or Yubikey.
- the `[C]` indicates the key is only capable of certification
- signing (`[S]`), encryption (`[E]`) and authentication (`[A]`) are all
  achieved by the individual subkeys
- the encryption key is 2048 bit so that it can be shared between multiple
  smartcards or yubikeys, among which the lowest common support is 2048 bit
  keys.  If your smartcards support higher sizes you can use the size you
  need.
- the signing and authentication keys are 4096 bit as they're generated on the
  card at the maximum supported bits for that specific card.

## Requirements

1. GnuPG >= 2.1
2. GNU Make
3. [Paperkey](http://www.jabberwocky.com/software/paperkey/)

### Recommended / optional extras

- Air gapped device.  Either a system that is not online, or make use of
  a live system image, with all connectivity disabled, possibly after
  downloading further requirements.
- One or two PGP/GPG smartcards, such as Yubikeys.
- At least two USB thumb drives to keep your master key safe.  You may want to
  consider using SLC sticks, and/or using [ZFSonLinux](http://zfsonlinux.org/)
  / [O3X](https://openzfsonosx.org/) to keep the keys safe from bitrot and
  device failure.  For a live OS image, [GhostBSD](http://ghostbsd.org/) works
  well, though it didn't boot on my 2013 Macbook Pro, so I used another old PC
  laptop.
- An additional USB thumb drive to transfer subkey shadows if using a
  SmartCard, or private subkeys if not using a smartcard, and public keys to
  your regular device.
- Access to a printer for creating your hard copies of your master key.

## <a name="scenario1"></a>Instructions for creating an airgapped key set with two yubikeys

These steps will take you through an example scenario.  Adjust as needed.

### Checklist

1. Two Yubikeys, one is a Neo (max 2048bit keys), and the other a Nano (max
   4096bit keys).
2. Four USB sticks:
    1. First a USB stick for the live OS image.
    2. Two that will store your secrets offline and should never be used in
       a networked device.  Ideally these are industrial quality, possibly
       SLC.
    3. One for transferring data across the air gap.
3. GhostBSD live image.  At the time of writing, the GhostBSD 11 beta images
   worked well, supports ZFS, and has up to date GPG packages.  You could also
   use any linux live system, such as [Tails](https://tails.boum.org), however
   be aware you won't get ZFS with that.  See the [Cold storage of the master
   key and revocation certificates](#zfs) section below for why ZFS would be
   of value.
4. Passwords you'll be using to protect your keys, and if you choose to use
   EncFS, then also for the encrypted mount.
5. Printer for the paper keys.

### Preparation

1. Prepare the USB drives for the OS, storing secrets, and for transferring
   keys.  If your primary workstation is Linux or Mac and you want to use ZFS,
   prepare the sticks before moving to the air gapped system.

      1. First, prepare your live OS image following the instructions for the
         live system you've chosen.

      2. At least two USB thumb drives for storing your secrets.  We'll
         refer to these as the *secure USB sticks* as they should ideally only
         be used on an air-gapped device.  See the section below on [Creating
         ZFS pools](#zfs) if that's how you'll be proceeding.

      3. One USB thumb drive for transferring data between workstation and the
         air-gapped device.  We'll refer to this as the *transfer USB stick*.
         It will contain a copy of this repository, GPG public keys and shadow
         keys.  No secrets will be stored on this, and any data on here can be
         recreated from the *secure USB sticks*.  See the section below on
         [Creating ZFS pools](#zfs) if that's how you'll be proceeding.

3. Clone this repository to the *transfer USB stick*.

### Generate the keys

These steps will prepare two SmartCards with secret subkeys, paperkey backups
that should be printed, and a revocation certificate in case the master key is
damaged or compromised.

1. Boot up the air-gapped system.

2. Get the live OS network connected, then get all the packages you'll need to
   complete this task, and finally disable networking.  For GhostBSD these are
   the steps:

    1. Establish a network connection, whether wired or wireless, using the
       GUI.
    2. In a terminal, get the necessary packages:

        sudo pkg install gnupg paperkey fusefs-encfs gmake

    3. Turn off networking:

        sudo service netif stop

3. Insert the *transfer USB stick*, mount it, and copy the
   gpg-smartcard-automation repository off the USB stick.  I recommend *not*
   working directly from the stick as I've experienced odd behaviours with the
   filesystems when doing this.

		mkdir ~ghostbsd/zpools
		sudo zpool import -R ~ghostbsd/zpools airgap-transfers
    sudo zpool scrub airgap-transfers
		cp -a ~/zpools/airgap-transfers/gpg-smartcard-automation ~/
		sudo zpool export airgap-transfers
		
4. Create your keyset:

    1. Prepare your working environment

        setenv GPGHOME $HOME/gpg-20170903
        cd ~/gpg-smartcard-automation

    2. Insert the first yubikey.  If you've not used the key before, or if
       you're recently reset it (try `gmake reset-yubikey`), then the default
       admin PIN is 12345678, and regular PIN is 123456.

        gmake default

       You'll be prompted for your password many times.  Follow the
       instructions in the output to complete this step.

    3. If you'll be using a second yubikey, insert it now.  The tooling will
       prepare another GPG homedir and keychain to work around a [GnuPG
       limitation that will be fixed by T2291](https://dev.gnupg.org/T2291).

        gmake import-secrets sckey

       You can skip this step if you're only preparing a single Yubikey.
		
    4. Copy data to USB sticks.  A series of helper scripts make this easy for
       you.

       1. Insert first *secure USB stick*, then
    
            ./copy-secrets-to-usb.sh $GPGHOME secure-1

          In this case, `secure-1` is the pool name for this USB stick.  This
          scripts assume you're using ZFS and EncFS.

       2. Repeat step 1 for additional *secure USB sticks*, adjusting the pool
          name as appropriate.

       3. Insert the *transfer USB stick* to copy the data destined for your
          main device.  As before, the second argument is the ZFS pool name.
          In this case there's no EncFS as there's nothing to be hidden here.

            ./copy-to-transfer-usb.sh $GPGHOME airgap-transfers

    5. Print the paper master key.  Ideally this will be via a USB connected
       printer rather than something wireless or networked.  The file to print
       is:

        $(GPGHOME)/DATA-airgapped/paperkey-master.txt
	
  At this point you're done with the air gapped live OS work!

5. Import your new keys to your main devices.

  1. Insert the *transfer USB stick* into your main device and copy the
     `$GPGHOME` path across to your system.  For example

        cp -a /Volumes/airgap-transfers/gpg-20170903 ~/ownCloud/

  2. If you prepared multiple Yubikeys, some files will be suffixed with the
     Yubikey serial number, for example
     `$GPGHOME/DATA-transferred/subkey-shadows-03821903.asc`.  Choose the one
     you want to import and pull it in.

        gpg --import < ~/ownCloud/gpg-20170903/DATA-transferred/subkey-shadows-03821903.asc

  3. Create the link between the imported shadows keys and your Yubikey:

        gpg --card-status

  4. If you want to use your other Yubikey with your mobile you'll need to
     import the other `subkey-shadows-*.asc` file into something like
     OpenKeyChain (for Android), then register your Yubikey with the app.

### What next

You may want to do a few further things to strengthen your key and web of
trust:

- Sign your new key with your old key.
- Upload your new public key to https://keybase.io
- Pull in the public keys for your second set of keys.

## <a name="scenario2"></a>Instructions for creating an airgapped soft key set

If you don't have a smartcard, you can generate only soft keys, with the
master key kept in cold storage, and your subkeys available to your every day
devices.  The benefit of this is that if your subkeys are compromised for any
reason, your web of trust doesn't break down due to the trust being anchored
to your master key.

The main difference here is that in step 4.2 of [the first
scenario](#scenario1), rather than running `gmake default`, you need to `gmake
softkeys`.  There are some further considerations for copying your secrets
across to the your main device, and those steps will be detailed soon.  Short
explanation is that you'll likely want to use an EncFS on your *transfer USB
stick* to keep those secrets less exposed.


## Usage

Use the built-in help for additional targets and usage.

    gmake help

## Key practices followed in this repository

### Offline master key

The master key is a soft key only capable of certification and should not be
stored on a device used daily.  It's a good idea to keep this safe on an
encrypted USB device, and even better to have a print out of it, as is
prepared by paperkey.

The generate master key backups are stored at:

  - $(GPGHOME)/DATA-airgapped/key-master.asc
  - $(GPGHOME)/DATA-airgapped/paperkey-master.txt

### Separate signing, encryption and authentication sub keys

When using Yubikeys or PGP/GPG smartcards, we want to have different signing
and authentication keys on each smartcard so that in the event one is lost we
only need to revoke that single key set of that token, plus the shared
encryption key.

The use of a shared encryption key is primarily for convenience: to have the
same encryption key used on both smartcards making it easy for others to send
us encrypted messages and not require them to have any knoweldge of our
PGP/GPG key structure.

For these reasons we generate the encryption key as a soft key that is
transferred to the smartcard, while we generate the signing and authentication
keys directly on the cards.

If you don't have a smartcard then you can generate all the keys as soft keys
using [scenario 2](#scenario2).

Storing and keeping the soft keys requires a little more prudence than when
using a smartcard.

### <a name="cold-storage"></a>Cold storage of the secret keys and revocation certificates

Ideally all your key material will be generated on an air gapped device, and
even better on a live OS so there's no persistence.  If you use an ephemeral
system for this, such as [Tails](https://tails.boum.org) or
[GhostBSD](https://ghostbsd.org), you'll need to keep your master key and
revocation certificates on a couple of USB thumb drives.

You should consider using SLC (Single Layer Cell) USB sticks as they should be
more resilient, and using a filesystem capable of bitrot detection and
recovery, such as ZFS.

You should also print out the paperkey representations of all private key
material as paper generally lasts a lot longer than USB thumb drives under
normal conditions.

### <a name="zfs"></a>Using ZFS and EncFS

Using ZFS offers several benefits:

- Interoperability between unix and macOs. On Linux this is availabe from the
  [ZFSonLinux](http://zfsonlinux.org/) project, and on macOS use
  [O3X](https://openzfsonosx.org/).  BSDs generally come with ZFS by default.

- Support for multiple copies of the data on a single drive.  If your USB
  thumbdrive were to experience bitflips/bitrot ZFS will return the correct
  data silently, though there are some caveates.  Details below.

Using EncFS on top of ZFS has the benefit of interoperability between unix
and macOS.

#### Creating ZFS pools

This section isn't comprehensive as there's enough documentation online,
however here's a quick start to creating a pool with multipe data copies on
a single stick:

1. Determine the device for your USB stick

       diskutil list

    Look for the device that corresponds to the characteristics of your stick
    and take node of the `/dev/diskX` title.

2. Create the new zpool.  This is a destructive operation on the USB stick, so
   be sure you know what you're doing.

       sudo zpool create -f -o ashift=12 -O copies=3 -O normalization=formD airgap-transfers /dev/diskX

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
- For some reason a Makefile seemed a good idea at the outset due to the fact
  we're creating many files and it should handle idempotence for us.  The code
  has probably grown beyond that and would benefit from a rewrite in something
  more suitable.

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
