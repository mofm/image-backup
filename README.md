# Image Backup Tool

"imagebackup.sh" script is a simple tool to backups disk to disk, disk to folder and image to disk.

## Usage

```

Usage: imagebackup.sh -s <source_disk> -d <destination_disk> -f <folder>

Options:
  -s <source_disk>           Source disk to backup
  -d <destination_disk>      Destination disk to backup
  -f <folder>                Destination folder to backup
  -i <image>                 Image file to backup

Example:
 disk to disk backup: imagebackup.sh -s /dev/sda -d /dev/sdb
 disk to folder backup: imagebackup.sh -s /dev/sda -f /mnt/backup
 image to disk backup: imagebackup.sh -i /mnt/image.img -d /dev/sdb

```
