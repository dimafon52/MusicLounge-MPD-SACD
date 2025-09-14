#!/usr/bin/env bash

# 26.08.25

# set -u
# # -u  Treat unset variables as an error when substituting.

OS=""
OS_VERSION=""
OS_PKG_MANAGER=""
OS_SUDO_GROUP=""
OS_SUDO_USER="NO"
OS_CMD_UPDATE=""
OS_CMD_INSTALL=""
OS_CMD_INSTALLED_PKGS=""

# os_install_pkgs(){
#     if [ "$OS_CMD_INSTALL"]
# }

os_sudo_access() {
    groups | grep -qwE "(wheel|sudo)"
    # or
    # id -nG | grep -qwE "(wheel|sudo)"
}

os_missing_pkgs(){
    local pkgs=($@)
    local missing=()

    if [ ! "$OS_CMD_INSTALLED_PKGS" ]; then
        if ! os_detect; then
            return 1
        fi
    fi
    
    for pkg in "${pkgs[@]}"; do
        $OS_CMD_INSTALLED_PKGS "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
    done
    
    echo "${missing[@]}"
}
# not_installed_pkgs=$(os_missing_pkgs "docker arp-scan smbclient")

os_detect() {
    local pkgmgr=""
    local group=""
    local cmd_update=""
    local cmd_install=""
    local cmd_installed_pkgs=""
    
    if command -v apt >/dev/null 2>&1; then
        pkgmgr="apt"
        group="sudo"
        cmd_update="sudo apt-get update"
        cmd_install="sudo apt-get install -y"
        cmd_installed_pkgs="sudo dpkg -s"
    elif command -v pacman >/dev/null 2>&1; then
        pkgmgr="pacman"
        group="wheel"
        cmd_update="sudo pacman -Syyu --noconfirm"
        cmd_install="sudo pacman -Sy --noconfirm"
        cmd_installed_pkgs="sudo pacman -Q"
    elif command -v apk >/dev/null 2>&1; then
        pkgmgr="apk"
        group="wheel"
        cmd_update="sudo apk update"
        cmd_install="sudo apk add"
        cmd_installed_pkgs="apk info -e"
    elif command -v dnf >/dev/null 2>&1; then
        pkgmgr="dnf"
        group="wheel"
        cmd_update="sudo dnf update"
        cmd_install="sudo dnf install -y"
        cmd_installed_pkgs="sudo rpm -q"
    elif command -v yum >/dev/null 2>&1; then
        pkgmgr="yum"
        group="wheel"
        cmd_update="sudo yum update"
        cmd_install="sudo yum install -y"
        cmd_installed_pkgs="sudo rpm -q"
    # elif command -v emerge >/dev/null 2>&1; then
    #     pkgmgr="emerge"
    #     group="wheel"
    # elif command -v pkg >/dev/null 2>&1; then
    #     pkgmgr="pkg"
    #     group="wheel"
    # elif command -v zypper >/dev/null 2>&1; then
    #     pkgmgr="zypper"
    #     group="wheel"
    else
        # echo "❌ Не удалось определить пакетный менеджер. Укажи вручную."
        echo "❌ Unable to determine package manager."
        return 1
    fi

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    fi
    
    OS_PKG_MANAGER=$pkgmgr
    OS_SUDO_GROUP=$group
    OS_CMD_UPDATE=$cmd_update
    OS_CMD_INSTALL=$cmd_install
    OS_CMD_INSTALLED_PKGS=$cmd_installed_pkgs
    
    # echo "📦 Обнаружен пакетный менеджер: $pkgmgr"
    # echo "👤 Пользователь должен быть в группе: $group"

    if id -nG "$USER" | grep -qw "$group"; then
        # echo "✅ Пользователь $USER уже в группе $group"
        OS_SUDO_USER="YES"
    else
        # echo "⚠️ Пользователь $USER НЕ в группе $group"
        echo " ⚠️ User '$USER' is NOT in group '$group' and cannot use sudo."
        # echo "➡️  Добавить можно так:"
        echo " ➡️  Access as root and add user '$USER' to group '$group':"
        echo "    su -"
        echo "    usermod -aG $group $USER"
        return 1
    fi
}
# # Usage:
# os_detect
# echo "OS_PKG_MANAGER: $OS_PKG_MANAGER"
# echo "OS_SUDO_GROUP:  $OS_SUDO_GROUP"
# echo "OS_SUDO_USER:   $OS_SUDO_USER"
### https://chatgpt.com/c/68989698-21b4-832e-857d-03eb9287eefc
# su
# echo $PATH
# # может остаться /usr/bin:/bin:/home/dima/.local/bin
# su -
# echo $PATH
# # будет /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin (чистое root-окружение)

VERSION=""
PACKAGETYPE=""
APT_KEY_TYPE="" # Only for apt-based distros
APT_SYSTEMCTL_START=false # Only needs to be true for Kali
os_detect2() {
    if [ -f /etc/os-release ]; then
		# /etc/os-release populates a number of shell variables. We care about the following:
		#  - ID: the short name of the OS (e.g. "debian", "freebsd")
		#  - VERSION_ID: the numeric release version for the OS, if any (e.g. "18.04")
		#  - VERSION_CODENAME: the codename of the OS release, if any (e.g. "buster")
		#  - UBUNTU_CODENAME: if it exists, use instead of VERSION_CODENAME
		. /etc/os-release
		case "$ID" in
			ubuntu|pop|neon|zorin|tuxedo)
				OS="ubuntu"
				if [ "${UBUNTU_CODENAME:-}" != "" ]; then
				    VERSION="$UBUNTU_CODENAME"
				else
				    VERSION="$VERSION_CODENAME"
				fi
				PACKAGETYPE="apt"
				# Third-party keyrings became the preferred method of
				# installation in Ubuntu 20.04.
				if expr "$VERSION_ID" : "2.*" >/dev/null; then
					APT_KEY_TYPE="keyring"
				else
					APT_KEY_TYPE="legacy"
				fi
				;;
			debian)
				OS="$ID"
				VERSION="$VERSION_CODENAME"
				PACKAGETYPE="apt"
				# Third-party keyrings became the preferred method of
				# installation in Debian 11 (Bullseye).
				if [ -z "${VERSION_ID:-}" ]; then
					# rolling release. If you haven't kept current, that's on you.
					APT_KEY_TYPE="keyring"
				# Parrot Security is a special case that uses ID=debian
				elif [ "$NAME" = "Parrot Security" ]; then
					# All versions new enough to have this behaviour prefer keyring
					# and their VERSION_ID is not consistent with Debian.
					APT_KEY_TYPE="keyring"
					# They don't specify the Debian version they're based off in os-release
					# but Parrot 6 is based on Debian 12 Bookworm.
					VERSION=bookworm
				elif [ "$VERSION_ID" -lt 11 ]; then
					APT_KEY_TYPE="legacy"
				else
					APT_KEY_TYPE="keyring"
				fi
				;;
			linuxmint)
				if [ "${UBUNTU_CODENAME:-}" != "" ]; then
				    OS="ubuntu"
				    VERSION="$UBUNTU_CODENAME"
				elif [ "${DEBIAN_CODENAME:-}" != "" ]; then
				    OS="debian"
				    VERSION="$DEBIAN_CODENAME"
				else
				    OS="ubuntu"
				    VERSION="$VERSION_CODENAME"
				fi
				PACKAGETYPE="apt"
				if [ "$VERSION_ID" -lt 5 ]; then
					APT_KEY_TYPE="legacy"
				else
					APT_KEY_TYPE="keyring"
				fi
				;;
			elementary)
				OS="ubuntu"
				VERSION="$UBUNTU_CODENAME"
				PACKAGETYPE="apt"
				if [ "$VERSION_ID" -lt 6 ]; then
					APT_KEY_TYPE="legacy"
				else
					APT_KEY_TYPE="keyring"
				fi
				;;
			parrot|mendel)
				OS="debian"
				PACKAGETYPE="apt"
				if [ "$VERSION_ID" -lt 5 ]; then
					VERSION="buster"
					APT_KEY_TYPE="legacy"
				else
					VERSION="bullseye"
					APT_KEY_TYPE="keyring"
				fi
				;;
			galliumos)
				OS="ubuntu"
				PACKAGETYPE="apt"
				VERSION="bionic"
				APT_KEY_TYPE="legacy"
				;;
			pureos|kaisen)
				OS="debian"
				PACKAGETYPE="apt"
				VERSION="bullseye"
				APT_KEY_TYPE="keyring"
				;;
			raspbian)
				OS="$ID"
				VERSION="$VERSION_CODENAME"
				PACKAGETYPE="apt"
				# Third-party keyrings became the preferred method of
				# installation in Raspbian 11 (Bullseye).
				if [ "$VERSION_ID" -lt 11 ]; then
					APT_KEY_TYPE="legacy"
				else
					APT_KEY_TYPE="keyring"
				fi
				;;
			kali)
				OS="debian"
				PACKAGETYPE="apt"
				YEAR="$(echo "$VERSION_ID" | cut -f1 -d.)"
				APT_SYSTEMCTL_START=true
				# Third-party keyrings became the preferred method of
				# installation in Debian 11 (Bullseye), which Kali switched
				# to in roughly 2021.x releases
				if [ "$YEAR" -lt 2021 ]; then
					# Kali VERSION_ID is "kali-rolling", which isn't distinguishing
					VERSION="buster"
					APT_KEY_TYPE="legacy"
				else
					VERSION="bullseye"
					APT_KEY_TYPE="keyring"
				fi
				;;
			Deepin|deepin)  # https://github.com/tailscale/tailscale/issues/7862
				OS="debian"
				PACKAGETYPE="apt"
				if [ "$VERSION_ID" -lt 20 ]; then
					APT_KEY_TYPE="legacy"
					VERSION="buster"
				else
					APT_KEY_TYPE="keyring"
					VERSION="bullseye"
				fi
				;;
			pika)
				PACKAGETYPE="apt"
				# All versions of PikaOS are new enough to prefer keyring
				APT_KEY_TYPE="keyring"
				# Older versions of PikaOS are based on Ubuntu rather than Debian
				if [ "$VERSION_ID" -lt 4 ]; then
					OS="ubuntu"
					VERSION="$UBUNTU_CODENAME"
				else
					OS="debian"
					VERSION="$DEBIAN_CODENAME"
				fi
				;;
			sparky)
				OS="debian"
				PACKAGETYPE="apt"
				VERSION="$DEBIAN_CODENAME"
				APT_KEY_TYPE="keyring"
				;;
			centos)
				OS="$ID"
				VERSION="$VERSION_ID"
				PACKAGETYPE="dnf"
				if [ "$VERSION" = "7" ]; then
					PACKAGETYPE="yum"
				fi
				;;
			ol)
				OS="oracle"
				VERSION="$(echo "$VERSION_ID" | cut -f1 -d.)"
				PACKAGETYPE="dnf"
				if [ "$VERSION" = "7" ]; then
					PACKAGETYPE="yum"
				fi
				;;
			rhel|miraclelinux)
				OS="$ID"
				if [ "$ID" = "miraclelinux" ]; then
					OS="rhel"
				fi
				VERSION="$(echo "$VERSION_ID" | cut -f1 -d.)"
				PACKAGETYPE="dnf"
				if [ "$VERSION" = "7" ]; then
					PACKAGETYPE="yum"
				fi
				;;
			fedora)
				OS="$ID"
				VERSION=""
				PACKAGETYPE="dnf"
				;;
			rocky|almalinux|nobara|openmandriva|sangoma|risios|cloudlinux|alinux|fedora-asahi-remix)
				OS="fedora"
				VERSION=""
				PACKAGETYPE="dnf"
				;;
			amzn)
				OS="amazon-linux"
				VERSION="$VERSION_ID"
				PACKAGETYPE="yum"
				;;
			xenenterprise)
				OS="centos"
				VERSION="$(echo "$VERSION_ID" | cut -f1 -d.)"
				PACKAGETYPE="yum"
				;;
			opensuse-leap|sles)
				OS="opensuse"
				VERSION="leap/$VERSION_ID"
				PACKAGETYPE="zypper"
				;;
			opensuse-tumbleweed)
				OS="opensuse"
				VERSION="tumbleweed"
				PACKAGETYPE="zypper"
				;;
			sle-micro-rancher)
				OS="opensuse"
				VERSION="leap/15.4"
				PACKAGETYPE="zypper"
				;;
			arch|archarm|endeavouros|blendos|garuda|archcraft|cachyos)
				OS="arch"
				VERSION="" # rolling release
				PACKAGETYPE="pacman"
				;;
			manjaro|manjaro-arm|biglinux)
				OS="manjaro"
				VERSION="" # rolling release
				PACKAGETYPE="pacman"
				;;
			alpine)
				OS="$ID"
				VERSION="$VERSION_ID"
				PACKAGETYPE="apk"
				;;
			postmarketos)
				OS="alpine"
				VERSION="$VERSION_ID"
				PACKAGETYPE="apk"
				;;
			nixos)
				echo "Please add Tailscale to your NixOS configuration directly:"
				echo
				echo "services.tailscale.enable = true;"
				exit 1
				;;
			bazzite)
				echo "Bazzite comes with Tailscale installed by default."
				echo "Please enable Tailscale by running the following commands as root:"
				echo
				echo "ujust enable-tailscale"
				echo "tailscale up"
				exit 1
				;;
			void)
				OS="$ID"
				VERSION="" # rolling release
				PACKAGETYPE="xbps"
				;;
			gentoo)
				OS="$ID"
				VERSION="" # rolling release
				PACKAGETYPE="emerge"
				;;
			freebsd)
				OS="$ID"
				VERSION="$(echo "$VERSION_ID" | cut -f1 -d.)"
				PACKAGETYPE="pkg"
				;;
			osmc)
				OS="debian"
				PACKAGETYPE="apt"
				VERSION="bullseye"
				APT_KEY_TYPE="keyring"
				;;
			photon)
				OS="photon"
				VERSION="$(echo "$VERSION_ID" | cut -f1 -d.)"
				PACKAGETYPE="tdnf"
				;;
		esac
	fi

    OS_VERSION=$VERSION
    if type $PACKAGETYPE >/dev/null 2>&1; then
        OS_PKG_MANAGER=$PACKAGETYPE
    fi
}
# # Usage:
# os_detect
# echo "OS:             $OS"
# echo "OS_VERSION:     $OS_VERSION"
# echo "OS_PKG_MANAGER: $OS_PKG_MANAGER"

os_missing_pkgs2() {
    local pkgs=($@)
    local missing=()
    local pkgmgr=""

    # Определяем пакетный менеджер
    if command -v pacman >/dev/null 2>&1; then
        pkgmgr="pacman"
    elif command -v apt >/dev/null 2>&1; then
        pkgmgr="apt"
    elif command -v emerge >/dev/null 2>&1; then
        pkgmgr="emerge"
    elif command -v yum >/dev/null 2>&1; then
        pkgmgr="yum"
    elif command -v dnf >/dev/null 2>&1; then
        pkgmgr="dnf"
    elif command -v apk >/dev/null 2>&1; then
        pkgmgr="apk"
    elif command -v pkg >/dev/null 2>&1; then
        pkgmgr="pkg"
    else
        echo "❌ Не удалось определить пакетный менеджер" >&2
        return 1
    fi

    # Проверка пакетов
    for pkg in "${pkgs[@]}"; do
        case "$pkgmgr" in
            pacman) pacman -Qi "$pkg" >/dev/null 2>&1 || missing+=("$pkg") ;;
            apt)    dpkg -s "$pkg"  >/dev/null 2>&1 || missing+=("$pkg") ;;
            emerge) equery list "$pkg" >/dev/null 2>&1 || missing+=("$pkg") ;;
            yum|dnf) rpm -q "$pkg" >/dev/null 2>&1 || missing+=("$pkg") ;;
            apk)    apk info -e "$pkg" >/dev/null 2>&1 || missing+=("$pkg") ;;
            pkg)    pkg info "$pkg" >/dev/null 2>&1 || missing+=("$pkg") ;;
        esac
    done

    echo "${missing[@]}"
}
