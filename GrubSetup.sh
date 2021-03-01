#!/bin/sh
# shellcheck disable=SC2181
#
# Script to set up the chroot'ed /etc/fstab
# - Pass in the name of the EBS device the chroot was built on
#   top of.
#
#################################################################
CHROOT="${CHROOT:-/mnt/ec2-root}"
CHROOTDEV=${1:-UNDEF}
CHGRUBDEF="${CHROOT}/etc/default/grub"

# Check for arguments
if [[ $# -lt 1 ]]
then
   echo "Missing parameter(s). Aborting..." > /dev/stderr
   exit 1
fi

# Make sure argument is valid
if [[ ! -e /sys/block/$(basename "${CHROOTDEV}") ]]
then
   echo "Invalid block device provided. Aborting..." > /dev/stderr
   exit 1
fi

(
printf "GRUB_TIMEOUT=1\n"
# shellcheck disable=2059
printf "GRUB_DISTRIBUTOR=\"$(sed 's, release .*$,,g' /etc/system-release)\"\n"
printf "GRUB_DEFAULT=saved\n"
printf "GRUB_DISABLE_SUBMENU=true\n"
printf "GRUB_DISABLE_LINUX_UUID=true\n"
printf "GRUB_DISABLE_RECOVERY=\"true\"\n"
printf "GRUB_TERMINAL_OUTPUT=\"console\"\n"
# Set GRUB2 vconsole output behavior
printf "GRUB_CMDLINE_LINUX=\"crashkernel=auto vconsole.keymap=us "
printf "vconsole.font=latarcyrheb-sun16 console=tty0 "
printf "console=ttyS0,115200n8 "
# Disable systemd's predictable network interface naming behavior
printf "net.ifnames=0 "
printf "boot=LABEL=/boot\"\n"
) > "${CHGRUBDEF}"

if [[ $? -ne 0 ]]
then
  echo "Failed..." >> /dev/stderr
  exit 1
fi

# Create and install a GRUB2 config file (etc.)
chroot "${CHROOT}" /bin/bash -c "/sbin/grub2-install ${CHROOTDEV}"
chroot "${CHROOT}" /bin/bash -c "/sbin/grub2-mkconfig  > /boot/grub2/grub.cfg"
CHROOTKRN=$(chroot "$CHROOT" rpm --qf '%{version}-%{release}.%{arch}\n' -q kernel)
chroot "${CHROOT}" dracut -fv "/boot/initramfs-${CHROOTKRN}.img" "${CHROOTKRN}"
