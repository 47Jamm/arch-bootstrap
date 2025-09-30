#!/bin/bash
set -e

### === USER CONFIG === ###
USERNAME="jamm"
HOSTNAME="RyzenSun"
DOTFILES_REPO="https://github.com/47Jamm/dotfiles.git"  # Replace this with your repo!
XDG_CONFIG_HOME="/home/$USERNAME/.config"

### === SYSTEM SETUP === ###
echo "==> Setting hostname..."
sudo hostnamectl set-hostname "$HOSTNAME"

echo "==> Adding user '$USERNAME' to all system groups..."
sudo usermod -aG wheel,audio,video,input,storage,optical,network,lp,syslog "$USERNAME"

echo "==> Enabling passwordless sudo for '$USERNAME'..."
echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/99_$USERNAME
sudo chmod 440 /etc/sudoers.d/99_$USERNAME

echo "==> Updating system..."
sudo pacman -Syu --noconfirm

echo "==> Installing essential packages..."
sudo pacman -S --noconfirm \
  git vim zsh bash wget curl unzip stow \
  alacritty \
  networkmanager \
  pipewire pipewire-pulse pipewire-alsa wireplumber \
  hyprland xwayland \
  openbox \
  greetd greetd-gtkgreet \
  wofi waybar \
  thunar ranger ueberzug \
  firefox \
  nvidia nvidia-utils nvidia-settings \
  xdg-desktop-portal xdg-desktop-portal-wlr \
  gvfs gvfs-mtp \
  ttf-jetbrains-mono ttf-font-awesome noto-fonts \
  wl-clipboard grim slurp swaybg dunst \
  starship \
  zsh-autosuggestions zsh-syntax-highlighting \
  base-devel

echo "==> Enabling NetworkManager..."
sudo systemctl enable NetworkManager

echo "==> Enabling PipeWire (user-level)..."
loginctl enable-linger "$USERNAME"
sudo -u "$USERNAME" systemctl --user enable pipewire pipewire-pulse wireplumber || echo "Will start after login."

echo "==> Setting Zsh as default shell for '$USERNAME'..."
chsh -s /bin/zsh "$USERNAME"

### === SETUP GREETD === ###
echo "==> Configuring greetd with GTKGreet..."
sudo mkdir -p /etc/greetd
sudo tee /etc/greetd/config.toml > /dev/null <<EOF
[terminal]
vt = 1

[default_session]
command = "gtkgreet -s Hyprland"
user = "$USERNAME"
EOF

sudo systemctl enable greetd

### === SETUP RANGER IMAGE PREVIEW === ###
echo "==> Configuring ranger image preview with ueberzug..."
sudo -u "$USERNAME" mkdir -p "/home/$USERNAME/.config/ranger"
sudo -u "$USERNAME" tee "/home/$USERNAME/.config/ranger/rc.conf" > /dev/null <<EOF
set preview_images true
set preview_images_method ueberzug
EOF

### === SETUP ZSH CONFIG === ###
echo "==> Configuring Zsh with Starship and plugins..."
ZSHRC="/home/$USERNAME/.zshrc"
sudo -u "$USERNAME" tee "$ZSHRC" > /dev/null <<EOF
# Zsh plugins
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Starship prompt
eval "\$(starship init zsh)"
EOF

### === INSTALL YAY (AUR HELPER) === ###
echo "==> Installing yay from AUR..."
cd /tmp
sudo -u "$USERNAME" git clone https://aur.archlinux.org/yay.git
cd yay
sudo -u "$USERNAME" makepkg -si --noconfirm
cd ..
rm -rf yay

### === CLONE DOTFILES & STOW === ###
echo "==> Cloning dotfiles..."
sudo -u "$USERNAME" git clone "$DOTFILES_REPO" "/home/$USERNAME/dotfiles"

echo "==> Using stow to symlink dotfiles..."
cd "/home/$USERNAME/dotfiles"
for dir in *; do
  if [ -d "$dir" ]; then
    sudo -u "$USERNAME" stow "$dir"
  fi
done

echo "==> Bootstrap complete. Reboot to enjoy your new system!"
