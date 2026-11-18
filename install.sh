#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLASMOID_SRC="$SCRIPT_DIR/plasmoid"
PLASMOID_ID="me.muriloscolari.darmoshark"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
TARGET_DIR="$DATA_DIR/plasma/plasmoids/$PLASMOID_ID"

UPSTREAM_REPO="https://github.com/ayasaki-exs/darmoshark-battery.git"
TELINK_FORK_REPO="https://github.com/muriloscolari/darmoshark-battery.git"
TELINK_FORK_BRANCH="feat/telink-248a-support"

DRIVER_MODE=""
AUTO_RESTART=0

usage() {
    cat <<'EOF'
Uso: ./install.sh [opções]

Opções:
  --with-aur       Instala a dependência darmoshark-battery-dkms-git via AUR (yay/paru)
  --with-source    Clona e instala o módulo darmoshark_battery via DKMS da source
  --skip-driver    Pula a verificação/instalação do módulo do kernel
  --restart        Reinicia o plasma-plasmashell.service automaticamente ao final
  -h, --help       Mostra esta ajuda
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --with-aur) DRIVER_MODE="aur" ;;
        --with-source) DRIVER_MODE="source" ;;
        --skip-driver) DRIVER_MODE="skip" ;;
        --restart) AUTO_RESTART=1 ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Opção desconhecida: $1" >&2
            usage
            exit 1
            ;;
    esac
    shift
done

install_driver_aur() {
    if command -v yay >/dev/null 2>&1; then
        yay -S --needed darmoshark-battery-dkms-git
    elif command -v paru >/dev/null 2>&1; then
        paru -S --needed darmoshark-battery-dkms-git
    else
        echo "Erro: yay ou paru não encontrados. Instale manualmente pelo AUR: darmoshark-battery-dkms-git" >&2
        return 1
    fi
    sudo modprobe darmoshark_battery || true
}

install_driver_source() {
    local branch_choice="1"
    local repo_url="$UPSTREAM_REPO"
    local branch="main"
    local tmp_dir

    for cmd in git make dkms sudo; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "Erro: comando obrigatório '$cmd' não encontrado. Instale git, base-devel, dkms e linux-headers." >&2
            return 1
        fi
    done

    if [ -t 0 ] && [ "$DRIVER_MODE" != "source" ]; then
        echo ""
        echo "Qual origem do módulo kernel deseja compilar?"
        echo "  1) Upstream (ayasaki-exs/darmoshark-battery - M3S Pro)"
        echo "  2) Fork com suporte Telink (muriloscolari/darmoshark-battery - M3, M3S, N3 + M3S Pro)"
        read -r -p "Escolha [1/2] (padrão 2): " branch_choice
        branch_choice="${branch_choice:-2}"
    else
        branch_choice="2"
    fi

    if [ "$branch_choice" = "2" ]; then
        repo_url="$TELINK_FORK_REPO"
        branch="$TELINK_FORK_BRANCH"
    fi

    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    echo "Clonando $repo_url (branch: $branch)..."
    git clone --branch "$branch" --depth 1 "$repo_url" "$tmp_dir/darmoshark-battery"
    pushd "$tmp_dir/darmoshark-battery" >/dev/null

    make test
    sudo dkms remove darmoshark-battery/0.1.0 --all >/dev/null 2>&1 || true
    sudo dkms add .
    sudo dkms build darmoshark-battery/0.1.0
    sudo dkms install darmoshark-battery/0.1.0
    printf 'darmoshark_battery\n' | sudo tee /etc/modules-load.d/darmoshark-battery.conf >/dev/null
    sudo modprobe -r darmoshark_battery >/dev/null 2>&1 || true
    sudo modprobe darmoshark_battery

    popd >/dev/null
}

check_driver() {
    if ls /sys/class/power_supply/darmoshark_battery_* >/dev/null 2>&1; then
        echo "[OK] Driver darmoshark_battery já está ativo no sistema."
        return 0
    fi

    if modinfo darmoshark_battery >/dev/null 2>&1; then
        echo "[INFO] Módulo darmoshark_battery encontrado, mas ainda não carregado ou mouse dormindo."
        if [ "$DRIVER_MODE" = "skip" ]; then
            return 0
        fi
        if [ -t 0 ] && [ -z "$DRIVER_MODE" ]; then
            read -r -p "Deseja tentar carregar o módulo agora com 'sudo modprobe darmoshark_battery'? [S/n] " ans
            if [[ ! "${ans:-S}" =~ ^[Nn]$ ]]; then
                sudo modprobe darmoshark_battery || true
            fi
        fi
        return 0
    fi

    echo ""
    echo "[AVISO] O módulo do kernel 'darmoshark_battery' não foi detectado."
    echo "Este widget depende dele para ler a bateria em /sys/class/power_supply/darmoshark_battery_*."
    echo "Repositório original: $UPSTREAM_REPO"

    if [ "$DRIVER_MODE" = "skip" ]; then
        return 0
    fi

    if [ "$DRIVER_MODE" = "aur" ]; then
        install_driver_aur
        return $?
    fi

    if [ "$DRIVER_MODE" = "source" ]; then
        install_driver_source
        return $?
    fi

    if [ -t 0 ]; then
        echo ""
        echo "Como deseja prosseguir?"
        echo "  1) Instalar via AUR (Arch Linux: darmoshark-battery-dkms-git)"
        echo "  2) Compilar e instalar via DKMS direto do código-fonte (recomendado p/ Darmoshark M3/M3S/N3)"
        echo "  3) Pular por enquanto e instalar apenas o widget"
        read -r -p "Escolha [1/2/3] (padrão 3): " choice
        case "${choice:-3}" in
            1) install_driver_aur ;;
            2) install_driver_source ;;
            *) echo "Pulando instalação do driver. Veja o README.md para instalar depois." ;;
        esac
    else
        echo "Execute com --with-aur ou --with-source para instalar o módulo do kernel, ou veja o README.md."
    fi
}

install_plasmoid() {
    echo ""
    echo "Instalando plasmoid $PLASMOID_ID..."

    if command -v kpackagetool6 >/dev/null 2>&1; then
        if [ -d "$TARGET_DIR" ]; then
            if ! kpackagetool6 -t Plasma/Applet -u "$PLASMOID_SRC" >/dev/null 2>&1; then
                rm -rf "$TARGET_DIR"
                kpackagetool6 -t Plasma/Applet -i "$PLASMOID_SRC"
            fi
        else
            kpackagetool6 -t Plasma/Applet -i "$PLASMOID_SRC"
        fi
    else
        mkdir -p "$TARGET_DIR"
        cp -a "$PLASMOID_SRC/." "$TARGET_DIR/"
    fi

    echo "[OK] Widget instalado em: $TARGET_DIR"
}

main() {
    check_driver
    install_plasmoid

    if [ "$AUTO_RESTART" -eq 1 ]; then
        systemctl --user restart plasma-plasmashell.service || true
    elif [ -t 0 ] && systemctl --user is-active plasma-plasmashell.service >/dev/null 2>&1; then
        read -r -p "Deseja reiniciar o plasmashell agora para atualizar o widget? [s/N] " restart_ans
        if [[ "${restart_ans:-N}" =~ ^[SsYy]$ ]]; then
            systemctl --user restart plasma-plasmashell.service
        fi
    fi

    echo ""
    echo "Pronto! Para adicionar à barra do KDE:"
    echo "  1. Clique com o botão direito no painel -> 'Adicionar ou gerenciar widgets...'"
    echo "  2. Pesquise por 'Darmoshark Battery' e arraste para o painel."
}

main
