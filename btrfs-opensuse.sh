#!/bin/bash
set -o pipefail

usage() {
	echo usage:
	echo btrfs-opensuse-style.sh device mountpoint
	echo
	echo "btrfs 'device' must be mounted at 'mountpoint' before running this script."
	exit 2
}

die() {
	echo "$@"
	exit 1
}

if (("$#" < "2")); then
	usage
fi

device="$1"
mnt="$2"
subs=(".snapshots" "boot" "home" "opt" "root" "srv" "tmp" "usr/local" "var")

btrfs subvolume create "${mnt}/@" || die "Could not create initial subvolume: @"
mkdir "${mnt}/@/usr"

for sub in "${subs[@]}"; do
	btrfs subvolume create "${mnt}/@/${sub}" || die "Could not create subvolume: ${sub}"
done

mkdir "${mnt}/@/.snapshots/1"
btrfs subvolume create "${mnt}/@/.snapshots/1/snapshot" ||
	die "Could not create initial snapshot"

chattr +C "${mnt}/@/var"
cat <<EOF >"${mnt}/@/.snapshots/1/info.xml"
<?xml version="1.0"?>
<snapshot>
  <type>single</type>
  <num>1</num>
  <date>$(date -u '+%F %T')</date>
  <description>first root filesystem</description>
</snapshot>
EOF

btrfs subvolume set-default "$(btrfs subvolume list "$mnt" |
	grep "@/.snapshots/1/snapshot" |
	grep -oP '(?<=ID )[0-9]+')" "$mnt" ||
	die "Error setting default subvolume"
umount "$mnt"
mount "$device" "$mnt" || die "Could not remount btrfs filesystem"

for sub in "${subs[@]}"; do
	mkdir -p "${mnt}/${sub}"
	mount "$device" "${mnt}/${sub}" -o "noatime,compress=zstd,subvol=@/${sub}" ||
		die "Could not mount subvolume: ${sub}"
done
