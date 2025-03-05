#!/usr/bin/env bash

main() {

  timedatectl set-timezone Europe/Berlin

  username
  hostname
  userpw
  rootpw
  device

  pacstrap /mnt base grub linux linux-firmware sof-firmware base-devel networkmanager efibootmgr neovim git --noconfirm --needed
  genfstab -U /mnt/ >/mnt/etc/fstab
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
  #TODO:Partitioning hint EFI, Root & Swap
  cfdisk "$DEVICE"

  if [[ "$DEVICE" == "/dev/nvme"* ]]; then

    mkfs.ext4 "$DEVICE"p2
    mkfs.fat -F32 "$DEVICE"p1
    mkswap "$DEVICE"p3

    mount "$DEVICE"p2 /mnt
    mkdir -pv /mnt/boot/efi
    mount "$DEVICE"p1 /mnt/boot/efi
    swapon "$DEVICE"p3
  else

    mkfs.ext4 "$DEVICE"2
    mkfs.fat -F32 "$DEVICE"1
    mkswap "$DEVICE"3

    mount "$DEVICE"2 /mnt
    mkdir -pv /mnt/boot/efi
    mount "$DEVICE"1 /mnt/boot/efi
    swapon "$DEVICE"3
  fi
}

username() {
  title="Username"
  type=inputbox
  text="Select username"
  wt2
  NAME="$result"
}

hostname() {
  title="Hostname"
  type=inputbox
  text="Select hostname"
  wt2
  HOSTNM="$result"
}
userpw() {
  title="User Password"
  type=passwordbox
  text="Select user password"
  wt2
  USERPW="$result"
}

rootpw() {
  title="Root Password"
  type=passwordbox
  text="Select root password"
  wt2
  ROOTPW="$result"
}
main
#TODO: optional package checkbox
#TODO:git clone post install script to desktop
#TODO:Add password later to install everything for AUR
cat <<REALEND >/mnt/next.sh
#!/usr/bin/env bash

ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
hwclock --systohc

sed -i "s/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen
sed -i "s/^#de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "LC_ALL=en_US.UTF-8" >> /etc/locale.conf

echo "$HOSTNM" > /etc/hostname
echo "$USER":"$ROOTPW" | chpasswd

useradd -m -G wheel -s /bin/bash "$NAME" 
echo "$NAME":"$USERPW" | chpasswd

sed -i "s/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/" /etc/sudoers

systemctl enable NetworkManager

grub-install "$DEVICE"
grub-mkconfig -o /boot/grub/grub.cfg

echo "KEYMAP=de-latin1" > /etc/vconsole.conf

sed -i "s/^#\[multilib\]/[multilib]/" /etc/pacman.conf
sed -i "/^\[multilib\]/ {n; s|^#Include = /etc/pacman.d/mirrorlist|Include = /etc/pacman.d/mirrorlist|}" /etc/pacman.conf

pacman -Syu --noconfirm --needed
pacman -S plasma sddm konsole kate dolphin fzf lsd fastfetch ncdu wikiman arch-wiki-docs btop openssh bluez bluez-utils npm ufw tldr man zenity lazygit bat pipewire pipewire-jack pipewire-pulse pipewire-alsa pipewire-audio wireplumber noto-fonts-cjk noto-fonts-emoji noto-fonts steam scrcpy gimp qbittorrent tealdeer man-db  jdk-openjdk jdk21-openjdk wine thunderbird ffmpeg xdg-desktop-portal-gtk linux-headers 7zip zenity libreoffice-fresh gwenview okular kdegraphics-thumbnailers ffmpegthumbs unzip --noconfirm --needed
pacman -S qemu-full virt-manager bridge-utils archlinux-keyring virt-viewer dnsmasq libguestfs ufw mono kdeconnect --noconfirm --needed

systemctl enable sddm

mkdir /home/"$NAME"/AUR/
(cd /home/"$NAME"/AUR && git clone https://aur.archlinux.org/yay.git && cd /home/"$USER"/AUR/yay && makepkg -sirc)
yay -S librewolf-bin wtf wireguird gpu-passthrough-manager polymc vesktop galaxybudsclient-bin qdiskinfo auto-cpufreq mono-git
# QEMU
# SSH
# UFW

cat <<EOF > /home/"$NAME"/.config/plasma-localerc
[Formats]
LANG=en_US.UTF-8
LC_ADDRESS=de_DE.UTF-8
LC_MEASUREMENT=de_DE.UTF-8
LC_MONETARY=de_DE.UTF-8
LC_NAME=de_DE.UTF-8
LC_NUMERIC=de_DE.UTF-8
LC_PAPER=de_DE.UTF-8
LC_TELEPHONE=de_DE.UTF-8
LC_TIME=de_DE.UTF-8

[Translations]
LANGUAGE=en_US
EOF


echo "______________________________________________________________"
echo "Installation complete, type "reboot" to reboot your system"
echo "______________________________________________________________"
REALEND

arch-chroot /mnt sh next.sh
