#!/bin/bash

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
  while true; do
    wt2
    USERPW="$result"
    text="Confirm user password"
    wt2
    CONFPW="$result"
    if [[ "$USERPW" == "$CONFPW" ]]; then
      break
    else
      text="Please try again, select user password"
      continue
    fi
  done
}

rootpw() {
  title="Root Password"
  type=passwordbox
  text="Select root password"
  while true; do
    wt2
    ROOTPW="$result"
    text="Confirm root password"
    wt2
    CONDPW="$result"
    if [[ "$ROOTPW" == "$CONDPW" ]]; then
      break
    else
      text="Please try again, select root password"
      continue
    fi
  done
}

main

#TODO: Package Array list packages=(a,b,c)
#TODO: .bashrc breaks because variables
#TODO: starship breaks
#TODO: lazyvim permissions break (myscripts git dir is root)
#TODO: Tip: curl into executable, don't pipe into shell
#TODO: Clear screen
#TODO: Ability to cancel
#TODO: Claritiy on select disk, which disk is which
#TODO: Partitioning hint EFI, Root & Swap
#TODO: auto-cpufreq & other Laptop packages and utilities
#TODO: DM, DE and browser choice
#TODO: optional package checkbox
#TODO: one time service to launch next script after restart
#TODO: Whiptail to launch next script
#TODO: custom grub.cfg & theme
#TODO: extract post-install to new script

# Login Manager/Desktp Manager
# ly sddm lightdm gdm etc
#
# Desktop Environemnt
# xfce plasma gnome cinnamon etc
#
# Browser
# LibreWolf Brave Midori QuteBrowser etc Chromium Gecko
#
# Terminal emulator
# konsole kitty alacritty ghostty etc
#
# shell
# bash zsh fish etc

cat <<REALEND >/mnt/next.sh
#!/bin/bash

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
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers.d/99_wheel-nopasswd
chmod 440 /etc/sudoers.d/99_wheel-nopasswd


systemctl enable NetworkManager.service


grub-install "$DEVICE"
grub-mkconfig -o /boot/grub/grub.cfg


echo "KEYMAP=de-latin1" > /etc/vconsole.conf


sed -i "s/^#\[multilib\]/[multilib]/" /etc/pacman.conf
sed -i "/^\[multilib\]/ {n; s|^#Include = /etc/pacman.d/mirrorlist|Include = /etc/pacman.d/mirrorlist|}" /etc/pacman.conf


cat << LIZ >> /etc/pacman.conf
[lizardbyte]
SigLevel = Optional
Server = https://github.com/LizardByte/pacman-repo/releases/latest/download

#[lizardbyte-beta]
#SigLevel = Optional
#Server = https://github.com/LizardByte/pacman-repo/releases/download/beta
LIZ


pacman -Syu --noconfirm --needed
pacman -S plasma sddm konsole kate dolphin fzf lsd fastfetch ncdu wikiman arch-wiki-docs btop rocm-smi-lib openssh bluez bluez-utils npm ufw man man-db zenity lazygit bat pipewire pipewire-jack pipewire-pulse pipewire-alsa pipewire-audio wireplumber noto-fonts-cjk noto-fonts-emoji noto-fonts steam scrcpy gimp qbittorrent tealdeer jdk-openjdk jdk21-openjdk mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon wine winetricks ffmpeg xdg-desktop-portal-gtk linux-headers 7zip zenity libreoffice-fresh gwenview okular kdegraphics-thumbnailers ffmpegthumbs unzip mono wine-mono kdeconnect obs-studio flatpak starship wget qemu-full virt-manager bridge-utils archlinux-keyring virt-viewer dnsmasq libguestfs timeshift wireguard-tools net-tools wol python-pip python-pipenv bind sunshine --noconfirm --needed

su - "$NAME" -c '(cd /home/"$NAME"/AUR && git clone https://aur.archlinux.org/yay.git && cd /home/"$NAME"/AUR/yay && makepkg -sirc --noconfirm)'
yes | yay -S qdiskinfo librewolf-bin betterbird-bin wtf wireguird polymc vesktop qdiskinfo mono-git --noconfirm --mflags --skippgpcheck

tldr --update
systemctl enable sddm.service
systemctl enable bluetooth.service
systemctl enable sshd.service
systemctl enable cronie.service


groupadd libvirtd
useradd -g "$NAME" libvirtd
usermod -aG libvirt "$NAME"
sed -i "s/^#unix_sock_group = "libvirt"/unix_sock_group = "libvirt"/" /etc/libvirt/libvirtd.conf
sed -i "s/^#unix_sock_rw_perms = "0770"/unix_sock_rw_perms = "0770"/" /etc/libvirt/libvirtd.conf
systemctl enable libvirtd.service


echo "#PasswordAuthentication no" > /etc/ssh/sshd_config.d/20-force_publickey_auth.conf         #configure manually
echo "#AuthenticationMethods publickey" >> /etc/ssh/sshd_config.d/20-force_publickey_auth.conf   #configure manually



(cd /home/"$NAME" && sudo -u "$NAME" mkdir -pv Ordner Desktop AUR git .config .local/share)
(cd /home/"$NAME"/.config && sudo -u "$NAME" mkdir -pv autostart btop fastfetch tealdeer)
(cd /home/"$NAME"/.local/share && sudo -u "$NAME" mkdir -pv fonts konsole)



(cd /home/"$NAME"/.local/share/fonts && wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Agave.zip && bsdtar xvf Agave.zip && fc-cache -fv)
(cd /home/"$NAME"/git && git clone https://github.com/CapuUnknown/my-scripts.git)
ln -s /home/"$NAME"/git/my-scripts/nvim /home/"$NAME"/.config
ln -s /home/"$NAME"/git/my-scripts/formatter.sh /usr/local/bin/formatter.sh
ln -s /home/"$NAME"/git/my-scripts/imagewriter.sh /usr/local/bin/imagewriter.sh
ln -s /home/"$NAME"/git/my-scripts/subs.sh /usr/local/bin/subs.sh
ln -s /home/"$NAME"/git/my-scripts/subs-all.sh /usr/local/bin/subs-all.sh
ln -s /home/"$NAME"/git/my-scripts/zen-iw.sh /usr/local/bin/zen-iw.sh
ln -s /home/"$NAME"/git/my-scripts/zen-subs.sh /usr/local/bin/zen-subs.sh
ln -s /home/"$NAME"/git/my-scripts/zipper.sh /usr/local/bin/zipper.sh



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


cat <<TLD > /home/"$NAME"/.config/tealdeer/config.toml
[updates]
auto_update = true
TLD


install -m 755 <(cat <<AUR
#!/bin/bash


cat <<UFW > /home/"$NAME"/Desktop/ufww.sh
#!/bin/bash

localectl set-keymap de-latin1

virsh net-start default
virsh net-autostart default

ufw enable
ufw allow from 192.168.178.0/24
ufw allow Deluge
ufw limit ssh

rm /home/"$NAME"/Desktop/ufww.sh

exit
UFW

sudo sh /home/"$NAME"/Desktop/ufww.sh

flatpak install com.bitwarden.desktop com.dec05eba.gpu_screen_recorder com.moonlight_stream.Moonlight com.spotify.Client com.vysp3r.ProtonPlus io.github.Qalculate io.github.flattool.Warehouse io.github.giantpinkrobots.flatsweep io.github.peazip.PeaZip io.missioncenter.MissionCenter me.timschneeberger.GalaxyBudsClient net.lutris.Lutris net.pcsx2.PCSX2 net.rpcs3.RPCS3 org.duckstation.DuckStation org.raspberrypi.rpi-imager -y

sudo rm /home/"$NAME"/Desktop/execute.sh

sudo pacman -Qdtq | sudo pacman -Rns -

exit
AUR
) /home/"$NAME"/Desktop/execute.sh
chown "$NAME":"$NAME" /home/"$NAME"/Desktop/execute.sh



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
alias zen-subs='zen-subs.sh'
alias convert='convert.sh'
alias formatter='formatter.sh'
alias imagewriter='imagewriter.sh'
alias procyon='ssh -Y capu@procyon'
alias ptolemy='ssh capu@ptolemy'

PS1='[\u@\h \W]\$ '

# Starship
if [ "$TERM" != "linux" ]; then
  eval "$(starship init bash)"
fi

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



clear
echo "___________________________________________________________"
echo "Installation complete, system will reboot in 5 seconds"
echo "___________________________________________________________"
echo

sleep 1 && echo "="
sleep 4

REALEND

arch-chroot /mnt sh next.sh

reboot now
