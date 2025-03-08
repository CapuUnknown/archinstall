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
#TODO: Starship
#TODO: agave font
#TODO: konsole profile
#TODO: Dolphin config
#TODO: scp apps or configs from file server
#TODO: Keyboard shortcuts
#TODO: Default applications
#TODO: autostart
#TODO: VPNs

cat <<REALEND >/mnt/next.sh
#!/usr/bin/env bash

ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
hwclock --systohc

sed -i "s/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen
sed -i "s/^#de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "LC_ALL=en_US.UTF-8" >> /etc/locale.conf

read -p "debug"
echo "$HOSTNM" > /etc/hostname
echo "$USER":"$ROOTPW" | chpasswd

useradd -m -G wheel -s /bin/bash "$NAME" 
echo "$NAME":"$USERPW" | chpasswd

read -p "debug"
sed -i "s/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/" /etc/sudoers

systemctl enable NetworkManager

read -p "debug"
grub-install "$DEVICE"
grub-mkconfig -o /boot/grub/grub.cfg

echo "KEYMAP=de-latin1" > /etc/vconsole.conf

read -p "debug"
sed -i "s/^#\[multilib\]/[multilib]/" /etc/pacman.conf
sed -i "/^\[multilib\]/ {n; s|^#Include = /etc/pacman.d/mirrorlist|Include = /etc/pacman.d/mirrorlist|}" /etc/pacman.conf

read -p "debug"
pacman -Syu --noconfirm --needed
read -p "debug"
pacman -S plasma sddm konsole kate dolphin fzf lsd fastfetch ncdu wikiman arch-wiki-docs btop rocm-smi-lib openssh bluez bluez-utils npm ufw tldr man man-db zenity lazygit bat pipewire pipewire-jack pipewire-pulse pipewire-alsa pipewire-audio wireplumber noto-fonts-cjk noto-fonts-emoji noto-fonts steam scrcpy gimp qbittorrent tealdeer jdk-openjdk jdk21-openjdk wine winetricks thunderbird ffmpeg xdg-desktop-portal-gtk linux-headers 7zip zenity libreoffice-fresh gwenview okular kdegraphics-thumbnailers ffmpegthumbs unzip mono wine-mono kdeconnect obs-studio flatpak starship wget --noconfirm --needed
read -p "debug"
pacman -S qemu-full virt-manager bridge-utils archlinux-keyring virt-viewer dnsmasq libguestfs --noconfirm --needed

read -p "debug"
tldr --update
systemctl enable sddm
systemctl enable bluetooth

read -p "debug"
groupadd libvirtd
useradd -g "$NAME" libvirtd
usermod -aG libvirt "$NAME"
read -p "debug"
sed -i "s/^#unix_sock_group = "libvirt"/unix_sock_group = "libvirt"/" /etc/libvirt/libvirtd.conf
sed -i "s/^#unix_sock_rw_perms = "0770"/unix_sock_rw_perms = "0770"/" /etc/libvirt/libvirtd.conf
systemctl enable libvirtd
read -p "debug"

echo "#PasswordAuthentication no" > /etc/ssh/ssh_config.d/20-force_publickey_auth.conf         #configure manually
echo "#AuthenticationMethod Publickey" >> /etc/ssh/ssh_config.d/20-force_publickey_auth.conf   #configure manually
read -p "debug"

mkdir -pv /home/"$NAME"/.config
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
read -p "debug"

mkdir -pv /home/"$NAME"/Desktop
touch /home/"$NAME"/Desktop/execute.sh
chmod 755 /home/"$NAME"/Desktop/execute.sh 

read -p "debug"
mkdir -pv /home/"$NAME"/.local/share/fonts
(cd /home/"$NAME"/.local/share/fonts && wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Agave.zip && bsdtar xvf Agave.zip && fc-cache -fv)
read -p "debug"

cat <<AUR > /home/"$NAME"/Desktop/execute.sh
#!/usr/bin/env bash

mkdir -pv /home/"$NAME"/AUR/
(cd /home/"$NAME"/AUR && git clone https://aur.archlinux.org/yay.git && cd /home/"$NAME"/AUR/yay && makepkg -sirc)
yes | yay -S qdiskinfo librewolf-bin wtf wireguird polymc vesktop qdiskinfo mono-git

cat <<UFW > /home/"$NAME"/Desktop/ufww.sh
#!/usr/bin/env bash

localectl set-keymap de-latin1

virsh net-start default
virsh net-autostart default

ufw enable
ufw allow from 192.168.178.0/24
ufw allow Deluge
ufw limit ssh

rm /home/"$NAME"/Desktop/ufww.sh
UFW

sudo /home/"$NAME"/Desktop/ufww.sh

flatpak install com.bitwarden.desktop com.dec05eba.gpu_screen_recorder com.moonlight_stream.Moonlight com.spotify.Client com.vysp3r.ProtonPlus io.github.Qalculate io.github.flattool.Warehouse io.github.giantpinkrobots.flatsweep io.github.peazip.PeaZip io.missioncenter.MissionCenter me.timschneeberger.GalaxyBudsClient net.lutris.Lutris net.pcsx2.PCSX2 net.rpcs3.RPCS3 org.duckstation.DuckStation org.raspberrypi.rpi-imager -y

rm /home/"$NAME"/Desktop/execute.sh
AUR

read -p "debug"
cat << STSH > /home/"$NAME"/.config/starship.toml
format = """\
[](bg:#232627 fg:#7DF9AA)\
[ ](bg:#7DF9AA fg:#000000)\
[](fg:#7DF9AA bg:#1C3A5E)\
$time[](fg:#1C3A5E bg:#3B76F0)\
$directory[](fg:#3B76F0 bg:#FCF392)\
$git_branch$git_status$git_metrics[](fg:#FCF392 bg:#232627)\
$character"""

[directory]
format = "[  $path ]($style)"
style = "fg:#E4E4E4 bg:#3B76F0"

[git_branch]
format = '[ $symbol$branch(:$remote_branch) ]($style)'
symbol = "  "
style = "fg:#1C3A5E bg:#FCF392"

[git_status]
format = '[$all_status]($style)'
style = "fg:#1C3A5E bg:#FCF392"

[git_metrics]
format = "([+$added]($added_style))[]($added_style)"
added_style = "fg:#1C3A5E bg:#FCF392"
deleted_style = "fg:bright-red bg:235"
disabled = false

[hg_branch]
format = "[ $symbol$branch ]($style)"
symbol = " "

[cmd_duration]
format = "[  $duration ]($style)"
style = "fg:bright-white bg:18"

[character]
success_symbol = '[ ➜](bold green) '
error_symbol = '[ ✗](#E84D44) '

[time]
disabled = false
time_format = "%R" # Hour:Minute Format
style = "bg:#1d2230"
format = '[[ 󱑍 $time ](bg:#1C3A5E fg:#8DFBD2)]($style)'
STSH

read -p "debug"
cat <<BRC > /home/"$NAME"/.bashrc
#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Aliases
alias s='source ~/.bashrc'
alias c='clear'
alias v='nvim'
# alias sudo='sudo '
alias cat='bat'
alias fzf='fzf --preview="cat {}"'
alias find='find 2>/dev/null'
alias ls='lsd --color=auto'
alias ll='ls -alF --color=auto'
alias grep='grep --color=auto'
alias disk='df -h'
alias ga='git add .'
alias gc='git commit'
alias gp='git push origin main'
alias gs='git status'
alias renamer='renamer.sh'
alias zipper='zipper.sh'
alias subs='subs.sh'
alias subs-all='subs-all.sh'
alias convert='convert.sh'
alias formatter='formatter.sh'
alias imagewriter='imagewriter.sh'
alias starpoint='ssh -Y capu@starpoint'
alias centurion='ssh -Y capu@centurion'
alias capuserver='ssh capu@192.168.178.57'

PS1='[\u@\h \W]\$ '

# Starship
eval "$(starship init bash)"

# Eternal bash history.
export HISTFILESIZE=
export HISTSIZE=

# Fastfetch
fastfetch

# fzf list & search
source <(fzf --bash)
HISTFILE=~/.bash_history

export MANPAGER='nvim +Man!'
BRC

read -p "debug"
echo "___________________________________________________________"
echo "Installation complete, type "reboot" to reboot your system"
echo "___________________________________________________________"

REALEND

arch-chroot /mnt sh next.sh

#reboot
