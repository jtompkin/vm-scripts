#!/bin/bash

usage() {
	echo Usage: "$0" device
	echo
	echo Arguments:
	echo "  device : block device to be formatted"
	exit 2
}

die() {
	echo "$@"
	exit 1
}

if (("$#" < "1")); then
	usage
fi

device="$1"

read -r -p "About to format ${device}. This will delete any data on ${device}. Continue? (y/N) " -N 1 cont
echo

if [[ "$cont" != "y" ]]; then
	die "Exited without formatting"
fi

echo Beginning formatting in 5 seconds...
echo Press CTRL+C to abort
sleep 5
echo Beginning formatting now...

linux_luks='CA7D7CCB-63ED-4C53-861C-1742536059CC'

parted "$device" mklabel gpt || die "Could not create device gpt label"
parted "$device" mkpart '"EFI system partition"' fat32 1MiB 1025MiB ||
	die "Could not create EFI system partition"
parted "$device" set 1 esp on
parted "$device" mkpart '"root crypt partition"' btrfs 1025MiB 100% ||
	die "Could not create root partition"
parted "$device" type 2 "$linux_luks"
