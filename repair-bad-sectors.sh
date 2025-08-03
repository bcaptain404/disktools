# way 1 - ext
sudo badblocks -v /dev/sda1 > ~/bad_sectors.txt
sudo e2fsck -l bad_sectors.txt /dev/sda1

# way 2 - ext
sudo e2fsck -cfpv /dev/sda1

# way 3 - all filesystems
sudo fsck -l bad_sectors.txt /dev/sda1

# source: https://www.debugpoint.com/2020/07/scan-repair-bad-sector-disk-linux/

