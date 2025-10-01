#!/bin/bash
set -euo pipefail

### === USER CONFIG === ###
USERNAME="RenZu"
HOSTNAME="RyzenSun"
DOTFILES_REPO="https://github.com/47Jamm/dotfiles.git"
XDG_CONFIG_HOME="/home/$USERNAME/.config"
WALLPAPER_URL="https://w.wallhaven.cc/full/zy/wallhaven-zyx123.jpg"  # change this!
WALLPAPER_PATH="$XDG_CONFIG_HOME/hypr/wallpaper.jpg"

### === SYSTEM SETUP === ###
echo "==> Setting hostname..."
sudo hostnamectl set-hostname "$HOSTNAME"

echo "==> Updating system..."
sudo pacman -Syu --noconfirm

echo "==> Installing essential packages..."
sudo pacman -S --needed --noconfirm \
  git vim zsh bash wget curl unzip stow \
  alacritty \
  networkmanager nm-applet \
  pipewire pipewire-pulse pipewire-alsa wireplumber \
  hyprland hyprpaper xorg-xwayland \
  openbox \
  greetd greetd-gtkgreet \
  wofi waybar \
  thunar ranger ueberzug \
  firefox \
  nvidia nvidia-utils nvidia-settings \
  xdg-desktop-portal xdg-desktop-portal-wlr \
  gvfs gvfs-mtp \
  ttf-jetbrains-mono ttf-font-awesome noto-fonts ttf-inconsolata \
  wl-clipboard grim slurp swaybg dunst \
  starship \
  zsh-autosuggestions zsh-syntax-highlighting \
  base-devel

### === NETWORKMANAGER & NM-APPLET SETUP === ###
echo "==> Enabling NetworkManager service..."
sudo systemctl enable NetworkManager

echo "==> Setting up nm-applet to autostart in Openbox..."
OB_AUTOSTART="/home/$USERNAME/.config/openbox/autostart"
mkdir -p "$(dirname "$OB_AUTOSTART")"
if ! grep -Fxq "nm-applet &" "$OB_AUTOSTART" 2>/dev/null; then
    echo "nm-applet &" >> "$OB_AUTOSTART"
fi

echo "==> Setting up nm-applet to autostart in Hyprland..."
HYPR_AUTOSTART="/home/$USERNAME/.config/hypr/autostart.sh"
mkdir -p "$(dirname "$HYPR_AUTOSTART")"
if ! grep -Fxq "nm-applet &" "$HYPR_AUTOSTART" 2>/dev/null; then
    echo "nm-applet &" >> "$HYPR_AUTOSTART"
fi

sudo -u "$USERNAME" chmod +x "$OB_AUTOSTART" "$HYPR_AUTOSTART"


echo "==> Enabling PipeWire (user-level)..."
loginctl enable-linger "$USERNAME"
systemctl --user enable --now pipewire pipewire-pulse wireplumber || echo "Will start after login."

echo "==> Setting Zsh as default shell..."
chsh -s /bin/zsh "$USERNAME"

### === SETUP GREETD === ###
echo "==> Configuring greetd with GTKGreet and GB keyboard..."
sudo mkdir -p /etc/greetd
sudo tee /etc/greetd/config.toml > /dev/null <<EOF
[default_session]
# Launch Hyprland with GB keyboard
command = "setxkbmap gb && Hyprland"
user = "$USERNAME"

[greeter]
# Use GTKGreet
path = "/usr/bin/gtkgreet"
user = "$USERNAME"
EOF

sudo systemctl enable greetd


[default_session]
command = "gtkgreet --cmd Hyprland"
user = "$USERNAME"
EOF

sudo systemctl enable greetd

### === SETUP RANGER IMAGE PREVIEW === ###
echo "==> Configuring ranger image preview..."
mkdir -p "$XDG_CONFIG_HOME/ranger"
tee "$XDG_CONFIG_HOME/ranger/rc.conf" > /dev/null <<EOF
set preview_images true
set preview_images_method ueberzug
EOF

### === SETUP ZSH CONFIG === ###
echo "==> Configuring Zsh with Starship and plugins..."
ZSHRC="/home/$USERNAME/.zshrc"
tee "$ZSHRC" > /dev/null <<EOF
# Zsh plugins
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Starship prompt
eval "\$(starship init zsh)"
EOF

### === INSTALL YAY (AUR HELPER) === ###
if ! command -v yay &>/dev/null; then
  echo "==> Installing yay from AUR..."
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  (cd /tmp/yay && makepkg -si --noconfirm)
  rm -rf /tmp/yay
fi

### === CLONE DOTFILES === ###
if [ ! -d "/home/$USERNAME/dotfiles" ]; then
  echo "==> Cloning dotfiles..."
  git clone "$DOTFILES_REPO" "/home/$USERNAME/dotfiles"
fi

### === STOW DOTFILES WITH PROGRAM CHECK === ###
echo "==> Using stow to symlink dotfiles..."
cd "/home/$USERNAME/dotfiles"

# Map configs to their corresponding programs
declare -A CONFIG_MAP=(
  [zsh]="zsh"
  [starship]="starship"
  [ranger]="ranger"
  [hypr]="Hyprland"
  [openbox]="openbox"
  [waybar]="waybar"
  [wofi]="wofi"
  [dunst]="dunst"
  [alacritty]="alacritty"
  [git]="git"
)

for dir in *; do
  if [ -d "$dir" ]; then
    bin="${CONFIG_MAP[$dir]:-}"
    if [ -n "$bin" ]; then
      if command -v "$bin" &>/dev/null; then
        echo "==> Stowing $dir (program: $bin)..."
        stow --adopt "$dir"
      else
        echo "==> Skipping $dir (program $bin not installed)..."
      fi
    else
      echo "==> No mapping for $dir, stowing anyway..."
      stow --adopt "$dir"
    fi
  fi
done

### === HYPRPAPER CONFIG === ###
echo "==> Setting up hyprpaper..."
mkdir -p "$XDG_CONFIG_HOME/hypr"
wget -O "$WALLPAPER_PATH" "$WALLPAPER_URL"

tee "$XDG_CONFIG_HOME/hypr/hyprpaper.conf" > /dev/null <<EOF
preload = $WALLPAPER_PATH
wallpaper = ,$WALLPAPER_PATH
EOF

### === SETUP DISPLAY MANAGER SESSIONS === ###
echo "==> Creating Openbox session file..."
sudo tee /usr/share/xsessions/openbox.desktop > /dev/null <<EOF
[Desktop Entry]
Name=Openbox
Comment=Lightweight X11 Window Manager
Exec=openbox-session
Type=Application
EOF

echo "==> Creating Hyprland session file..."
sudo tee /usr/share/wayland-sessions/hyprland.desktop > /dev/null <<EOF
[Desktop Entry]
Name=Hyprland
Comment=Wayland Compositor
Exec=Hyprland
Type=Application
EOF

echo "==> Adding Openbox to Hyprland autostart..."
echo "openbox &" >> "/home/$USERNAME/.config/hypr/autostart.sh"
sudo -u "$USERNAME" chmod +x "/home/$USERNAME/.config/hypr/autostart.sh"


### === DONE === ###
echo "==> Bootstrap complete. Reboot to enjoy your new system!"
