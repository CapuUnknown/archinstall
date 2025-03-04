#!/usr/bin/env bash

main() {

  echo "timedatectl set-timezone Europe/Berlin"

  username
  hostname
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
  DEVICE="$result"
  if [[ "$DEVICE" == "/dev/nvme"* ]]; then

    echo "mkfs.ext4 ""$DEVICE""p2"
    echo "mkfs.fat -F32 ""$DEVICE""p1"
    echo "mkswap ""$DEVICE""p3"

    echo "mount ""$DEVICE""p2 /mnt"
    echo "mkdir -pv /mnt/boot/efi"
    echo "mount ""$DEVICE""p1 /mnt/boot/efi"
    echo "swapon ""$DEVICE""p3"
  else

    echo "mkfs.ext4 ""$DEVICE""2"
    echo "mkfs.fat -F32 ""$DEVICE""1"
    echo "mkswap ""$DEVICE""3"

    echo "mount ""$DEVICE""2 /mnt"
    echo "mkdir -pv /mnt/boot/efi"
    echo "mount ""$DEVICE""1 /mnt/boot/efi"
    echo "swapon ""$DEVICE""3"
  fi
}

username() {
  title="Username"
  type=inputbox
  text="Select username"
  wt2
  echo "$result"
  NAME="$result"
}

hostname() {
  title="Hostname"
  type=inputbox
  text="Select hostname"
  wt2
  echo "$result"
  HOSTNAME="$result"
}

main
#TODO: optional package checkbox
cat <<REALEND >/mnt/next.sh
#!/usr/bin/env bash

ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
hwclock --systohc

sed -i "s/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen
sed -i "s/^#de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "LC_ALL=en_US.UTF-8" >> /etc/locale.conf

echo "$HOSTNAME" > /etc/hostname
rootpw=($(whiptail --passwordbox --title "Root Password" --text "Select root password" 3>&1 1>&2 2>&3))
echo "$USER":"$rootpw" | chpasswd

useradd -m -G wheel -s /bin/bash "$NAME" 
userpw=($(whiptail --passwordbox --title "User Password" --text "Select user password" 3>&1 1>&2 2>&3))
echo "$NAME":"$userpw" | chpasswd

sed -i "s/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/" /etc/sudoers

systemctl enable NetworkManager

grub-install "$DEVICE"
grub-mkconfig -o /boot/grub/grub.cfg

echo "KEYMAP=de-latin1" > /etc/vconsole.conf
REALEND

arch-chroot /mnt sh next.sh
