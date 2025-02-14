#!/bin/bash

usage() {
	printf 'usage: %s device\n\n' "$(basename "$0")"
	printf 'arguments:\n'
	printf '\tdevice : block device to be formatted\n'
	exit 1
}

die() {
	echo "$@" >&2
	exit 2
}

if (("$#" < "1")); then
	usage
fi

device="$1"

read -r -p "About to format ${device}. This will delete any data on ${device}. Continue? (y/N) " -N 1 cont
printf '\n' >&2

if [[ "$cont" != "y" ]]; then
	die "Exited without formatting"
fi

printf 'Press CTRL+C to abort...\n'
printf 'Starting in... \x1b[31m'
for i in $(seq 5 -1 1); do
	printf '%d ' "$i"
	sleep 1
done
printf '\x1b[0m\nBeginning formatting now...\n'

linux_luks='CA7D7CCB-63ED-4C53-861C-1742536059CC'

parted -s "$device" mklabel gpt || die "Could not create device gpt label"
parted -s "$device" mkpart '"EFI system partition"' fat32 1MiB 1025MiB ||
	die "Could not create EFI system partition"
parted -s "$device" set 1 esp on
parted -s "$device" mkpart '"root crypt partition"' btrfs 1025MiB 100% ||
	die "Could not create root partition"
parted -s "$device" type 2 "$linux_luks"
