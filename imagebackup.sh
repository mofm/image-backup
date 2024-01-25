#!/usr/bin/env bash
# This script will backup the images from disk to another disk(like hdd) to specific folder
# It will check the disk space before backup and will not backup if the host disk space is less than source disk space


# dd command variables
BLOCK_SIZE=1M
OPT_CONV=sync,noerror
OPT_STATUS=progress


die() {
  printf '\033[1;31mERROR:\033[0m %s\n' "$@" >&2  # bold red
  exit 1
}


einfo() {
  printf '\033[1;32mINFO:\033[0m %s\n' "$@" >&2  # bold green
}


ewarn() {
  printf '\033[1;33mWARN:\033[0m %s\n' "$@" >&2  # bold yellow
}


function help {
  echo ""
  echo "Usage: imagebackup.sh -s <source_disk> -d <destination_disk> -f <folder> -i <image>"
  echo ""
  echo "Options:"
  echo "  -s <source_disk>           Source disk to backup"
  echo "  -d <destination_disk>      Destination disk to backup"
  echo "  -f <folder>                Destination folder to backup"
  echo "  -i <image>                 Image file to backup"
  echo ""
  echo "Example:"
  echo " disk to disk backup: imagebackup.sh -s /dev/sda -d /dev/sdb"
  echo " disk to folder backup: imagebackup.sh -s /dev/sda -f /mnt/backup"
  echo " image to disk backup: imagebackup.sh -i /mnt/image.img -d /dev/sdb"
}

# Check getopts counts and print help.
if [ $# -ne 4 ]; then
  help
  exit 1
fi


while getopts "s:d:f:i:h:" opt; do
  case $opt in
    s)
      echo "== Source disk is $OPTARG ==" >&2
      source_disk="$OPTARG"
    ;;
    d)
      echo "== Destination disk is $OPTARG ==" >&2
      destination_disk="$OPTARG"
    ;;
    f)
      echo "== Destination folder is $OPTARG ==" >&2
      folder="$OPTARG"
    ;;
    i)
      echo "== Image file is $OPTARG ==" >&2
      image="$OPTARG"
    ;;
    h)
      help
      exit 0
    ;;
    \?)
      echo "== Invalid option -$OPTARG ==" >&2
      exit 1
    ;;
  esac
done


# check if user is root
function check_root {
  if [ "$EUID" -ne 0 ]; then
    die "Please run as root"
  fi
}


# check if block device is exist in the system
function check_disk {
  if [ ! -b "$1" ]; then
    die "$1 block device is not exist in the system"
  fi
}


# check if directory is exist in the system
function check_directory {
  if [ ! -d "$1" ]; then
    die "$1 directory is not exist or not a directory"
  fi
}


# check if image file is exist in the system
function check_file_exist {
  if [ -f "$1" ]; then
    ewarn "$1 is exist in the system"
    ewarn "Do you want to overwrite? [y/N]"
    read -r answer
    if [ "$answer" != "y" ]; then
      die "Aborting"
    fi
  fi
}


# check if image file is exist and image format is correct
function check_image {
  if [ ! -f "$1" ]; then
    die "$1 is not exist in the system"
  fi
  if ! file "$1" | grep -q "DOS/MBR boot sector"; then
    die "$1 is not a valid image file"
  fi
}


# umount block device partition(s) if it is mounted
function umount_disk {
  local mounted_partitions
  mounted_partitions=$(grep "$1" /proc/mounts | awk '{print $1}')
  if [ ${#mounted_partitions[@]} -ne 0 ]; then
    for partition in $mounted_partitions; do
      einfo "== $partition is mounted, umounting $partition =="
      umount "$partition" || die "Failed to umount $partition"
    done
  fi
}


# check if destination disk space is less than source disk space
function check_block_size {
  source_disk_space=$(blockdev --getsize64 "$1")
  destination_disk_space=$(blockdev --getsize64 "$2")
  if [ "$source_disk_space" -gt "$destination_disk_space" ]; then
    die "Destination disk space is less than source disk space"
  fi
}


# check if host disk space is not enough to backup image
function check_host_disk_space {
  source_disk_space=$(blockdev --getsize64 "$1")
  host_disk_space=$(df -B1 --output=avail "$2" | tail -n1)
  if [ "$source_disk_space" -gt "$host_disk_space" ]; then
    die "Host disk space is not enough to backup image"
  fi
}


# check if destination disk space size for image is not enough
function check_image_disk_space {
  image_size=$(stat -c %s "$1")
  destination_disk_space=$(blockdev --getsize64 "$2")
  if [ "$image_size" -gt "$destination_disk_space" ]; then
    die "Destination disk space is not enough to backup image"
  fi
}


# clone function
function clone_disk {
  # last chance to abort
  ewarn "== The script will clone $1 to $2 =="
  ewarn "Are you sure? [y/N]"
  read -r answer
  if [ "$answer" != "y" ]; then
    echo "== Aborting =="
    exit 1
  fi
  einfo "== Cloning $1 to $2 =="
  dd if="$1" of="$2" bs="$BLOCK_SIZE" conv="$OPT_CONV" status="$OPT_STATUS" || die "Failed to clone $1 to $2"
  # to make sure the disk is synced
  sync
  einfo "== Cloning is successful =="
}


# Finally, check which variables are empty and run functions
function main {
  check_root
  if [ -n "$source_disk" ] && [ -n "$destination_disk" ]; then
    check_disk "$source_disk"
    check_disk "$destination_disk"
    # check if source disk and destination disk is same
    if [ "$source_disk" == "$destination_disk" ]; then
      die "Source disk and destination disk is same"
    fi
    check_block_size "$source_disk" "$destination_disk"
    umount_disk "$source_disk"
    umount_disk "$destination_disk"
    clone_disk "$source_disk" "$destination_disk"
  elif [ -n "$source_disk" ] && [ -n "$folder" ]; then
    check_disk "$source_disk"
    check_directory "$folder"
    check_file_exist "$folder/image-$(date +%d%m%y).img"
    check_host_disk_space "$source_disk" "$folder"
    umount_disk "$source_disk"
    clone_disk "$source_disk" "$folder/image-$(date +%d%m%y).img"
  elif [ -n "$image" ] && [ -n "$destination_disk" ]; then
    check_disk "$destination_disk"
    check_image "$image"
    check_image_disk_space "$image" "$destination_disk"
    umount_disk "$destination_disk"
    clone_disk "$image" "$destination_disk"
  else
    help
    exit 1
  fi
}


main
