#!/usr/bin/env bash

main() {

  echo "timedatectl set-timezone Europe/Berlin"

  username
  hostname
  user-pw
  root-pw
  device

  echo "pacstrap -K /mnt base grub linux linux-firmware sof-firmware base-devel networkmanager efibootmgr neovim git --noconfirm --needed"
  echo "genfstab -U /mnt/ > /mnt/etc/fstab"
}

wt1() {
  result=$(
    whiptail --title "$title" \
      --"$type" "$text" 22 78 12 "${options[@]}" \
      3>&1 1>&2 2>&3
  )
}

wt2() {
  result=$(
    whiptail --title "$title" \
      --"$type" "$text" 22 78 \
      3>&1 1>&2 2>&3
  )

}

device() {
  title="Partitioning"
  type="radiolist"
  text="Select disk device"

  mapfile -t devices < <(lsblk -dno NAME | grep -E "^sd|nvme|vd")
  options=()

  for dev in "${devices[@]}"; do
    options+=("/dev/$dev" "" OFF)
  done
  while true; do
    wt1
    if [[ "$result" == "" ]]; then
      continue
    else
      break
    fi
  done

  if [[ "$result" == "/dev/nvme"* ]]; then

    echo "mkfs.ext4 ""$result""p2"
    echo "mkfs.fat -F32 ""$result""p1"
    echo "mkswap ""$result""p3"

    echo "mount ""$result""p2 /mnt"
    echo "mkdir -pv /mnt/boot/efi"
    echo "mount ""$result""p1 /mnt/boot/efi"
    echo "swapon ""$result""p3"
  else

    echo "mkfs.ext4 ""$result""2"
    echo "mkfs.fat -F32 ""$result""1"
    echo "mkswap ""$result""3"

    echo "mount ""$result""2 /mnt"
    echo "mkdir -pv /mnt/boot/efi"
    echo "mount ""$result""1 /mnt/boot/efi"
    echo "swapon ""$result""3"
  fi
}

root-pw() {
  title="Root Password"
  type=passwordbox
  text="Select root password"
  wt2
  echo "$result"
}

user-pw() {
  title="User Password"
  type=passwordbox
  text="Select user password"
  wt2
  echo "$result"
}

username() {
  title="Username"
  type=inputbox
  text="Select username"
  wt2
  echo "$result"
}

hostname() {
  title="Hostname"
  type=inputbox
  text="Select hostname"
  wt2
  echo "$result"
}

main
#TODO: optional package checkbox
cat <<REALEND >/mnt/next.sh
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
hwclock --systohc
# /etc/locale.gen
locale-gen
# /etc/locale.conf
# hostname
# root password
# useradd -m -G wheel -s /bin/bash name 
# user password
# visudo wheel
systemctl enable NetworkManager
# grub-install device
grub-mkconfig -o /boot/grub/grub.cfg
# cat "KEYMAP=de-latin1" > /etc/vconsole.conf
# multilib
# pacman
systemctl enable sddm
mkdir /home/"$USER"/AUR
(cd /home/"$USER/AUR" && git clone https://aur.archlinux.org/yay.git && cd /home/"$USER"/AUR/yay && makepkg -sirc)
yay -S librewolf-bin wtf wireguird gpu-passthrough-manager polymc vesktop galaxybudsclient-bin qdiskinfo auto-cpufreq mono-git
# QEMU
# SSH
REALEND

arch-chroot /mnt sh next.sh
