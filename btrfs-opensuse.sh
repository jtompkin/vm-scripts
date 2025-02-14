#!/bin/bash
set -o pipefail

usage() {
	printf 'usage: %s device mountpoint [zstd-compress-num]\n\n' "$(basename "$0")"
	printf "arguments:\n"
	printf "\tdevice            : btrfs formatted block device\n"
	printf "\tmountpoint        : mount point of 'device'\n"
	printf "\tzstd-compress-num : compression number for btrfs (default 3)\n\n"
	printf "'device' must be mounted at 'mountpoint' before running script\n"
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
compress="3"
if [[ -n "$3" ]]; then
	compress="$3"
fi
if [[ "$4" == "_TEST" ]]; then
	die "$1 $2 $3"
fi

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
mount "$device" "$mnt" -o "noatime,compress=zstd:${compress}" ||
	die "Could not remount btrfs filesystem"

for sub in "${subs[@]}"; do
	mkdir -p "${mnt}/${sub}"
	mount "$device" "${mnt}/${sub}" -o "noatime,compress=zstd,subvol=@/${sub}" ||
		die "Could not mount subvolume: ${sub}"
done
