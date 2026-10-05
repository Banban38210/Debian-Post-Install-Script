#!/usr/bin/env bash

# Vérification que le script est bien exécuté en tant que root
if [ "$(id -u)" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root." >&2
    exit 1
fi

echo "=== Début de la post-installation Debian ==="

# -----------------------------------------------------------------------------
# 1. Choix de la branche (Stable vs Sid) et configuration de sources.list
# -----------------------------------------------------------------------------
echo ""
read -rp "Souhaites-tu passer sur Debian Sid (Unstable) ? (y/N) : " choice_sid

# Sauvegarde du sources.list original
cp /etc/apt/sources.list /etc/apt/sources.list.bak

if [[ "$choice_sid" =~ ^[Yy]$ ]]; then
    echo "Configuration des sources pour Debian Sid..."
    cat <<'EOF' > /etc/apt/sources.list
deb http://deb.debian.org/debian/ sid main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ sid main contrib non-free non-free-firmware
EOF
    # En Sid, installation de Firefox (version standard)
    BROWSER_PACKAGES=(firefox firefox-l10n-fr)
else
    echo "Conservation de Debian Stable (activation de contrib, non-free, non-free-firmware)..."
    CODENAME=$(lsb_release -sc 2>/dev/null || echo "stable")
    cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian/ $CODENAME main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ $CODENAME main contrib non-free non-free-firmware

deb http://security.debian.org/debian-security ${CODENAME}-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security ${CODENAME}-security main contrib non-free non-free-firmware

deb http://deb.debian.org/debian/ ${CODENAME}-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ ${CODENAME}-updates main contrib non-free non-free-firmware
EOF
    # En Stable, installation de Firefox ESR
    BROWSER_PACKAGES=(firefox-esr firefox-esr-l10n-fr)
fi

# -----------------------------------------------------------------------------
# 2. Base de paquets obligatoires et questions interactives
# -----------------------------------------------------------------------------
# Liste de base + le Firefox adapté à la branche choisie
PACKAGES_TO_INSTALL=(
    kde-plasma-desktop
    ark
    gwenview
    okular
    print-manager
    network-manager
    "${BROWSER_PACKAGES[@]}"
)

echo ""
echo "--- Choix des logiciels optionnels ---"

# LibreOffice
read -rp "Voudrais-tu LibreOffice sur ton système ? (y/N) : " opt_office
if [[ "$opt_office" =~ ^[Yy]$ ]]; then
    PACKAGES_TO_INSTALL+=(libreoffice libreoffice-kf6 libreoffice-grammalecte libreoffice-l10n-fr)
fi

# Thunderbird
read -rp "Voudrais-tu Thunderbird sur ton système ? (y/N) : " opt_thunderbird
if [[ "$opt_thunderbird" =~ ^[Yy]$ ]]; then
    PACKAGES_TO_INSTALL+=(thunderbird thunderbird-l10n-fr)
fi

# GIMP
read -rp "Voudrais-tu GIMP sur ton système ? (y/N) : " opt_gimp
if [[ "$opt_gimp" =~ ^[Yy]$ ]]; then
    PACKAGES_TO_INSTALL+=(gimp)
fi

# Amarok
read -rp "Voudrais-tu Amarok sur ton système ? (y/N) : " opt_amarok
if [[ "$opt_amarok" =~ ^[Yy]$ ]]; then
    PACKAGES_TO_INSTALL+=(amarok)
fi

# K3b
read -rp "Voudrais-tu K3b sur ton système ? (y/N) : " opt_k3b
if [[ "$opt_k3b" =~ ^[Yy]$ ]]; then
    PACKAGES_TO_INSTALL+=(k3b flac opus-tools vorbis-tools)
fi

# Steam
read -rp "Voudrais-tu Steam sur ton système ? (y/N) : " opt_steam
if [[ "$opt_steam" =~ ^[Yy]$ ]]; then
    dpkg --add-architecture i386
    PACKAGES_TO_INSTALL+=(steam-installer)
fi

# Audacity
read -rp "Voudrais-tu Audacity sur ton système ? (y/N) : " opt_audacity
if [[ "$opt_audacity" =~ ^[Yy]$ ]]; then
    PACKAGES_TO_INSTALL+=(audacity)
fi

# Kdenlive
read -rp "Voudrais-tu Kdenlive sur ton système ? (y/N) : " opt_kdenlive
if [[ "$opt_kdenlive" =~ ^[Yy]$ ]]; then
    PACKAGES_TO_INSTALL+=(kdenlive)
fi

# -----------------------------------------------------------------------------
# 3. Mise à jour du système et installation des paquets
# -----------------------------------------------------------------------------
echo ""
echo "=== Mise à jour des dépôts et du système ==="
apt-get update -y
apt-get dist-upgrade -y

echo ""
echo "=== Installation des paquets sélectionnés ==="
apt-get install -y "${PACKAGES_TO_INSTALL[@]}"

# -----------------------------------------------------------------------------
# 4. Modification de /etc/network/interfaces
# -----------------------------------------------------------------------------
echo ""
echo "=== Configuration de /etc/network/interfaces ==="
if [ -f /etc/network/interfaces ]; then
    cp /etc/network/interfaces /etc/network/interfaces.bak
    # Mettre un '#' en début de chaque ligne non vide et non commentée
    sed -i '/^[[:space:]]*[^#]/ s/^/#/' /etc/network/interfaces
    echo "Toutes les lignes de /etc/network/interfaces ont été commentées."
fi

# Activer et démarrer NetworkManager
systemctl enable --now NetworkManager

# -----------------------------------------------------------------------------
# 5. Modification de /etc/default/grub et update-grub
# -----------------------------------------------------------------------------
echo ""
echo "=== Configuration de GRUB ==="
GRUB_FILE="/etc/default/grub"

if [ -f "$GRUB_FILE" ]; then
    cp "$GRUB_FILE" "${GRUB_FILE}.bak"

    # Ajout de splash et zswap.enabled=1 s'ils ne sont pas déjà présents
    if ! grep -q "zswap.enabled=1" "$GRUB_FILE"; then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="splash zswap.enabled=1 /' "$GRUB_FILE"
    fi

    # Nettoyage des éventuels espaces doubles générés
    sed -i 's/  */ /g' "$GRUB_FILE"

    echo "Mise à jour de GRUB..."
    update-grub
fi

echo ""
echo "=== Post-installation terminée avec succès ! ==="
echo "Un redémarrage est recommandé pour appliquer l'ensemble des modifications."