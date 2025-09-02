#!/usr/bin/env bash
################################################################################
# Blueprint Installer for Pterodactyl (menu-driven, guldkage-style)
# Author: You + WH
# Target: /var/www/pterodactyl
# License: MIT (adjust as you prefer)
################################################################################
set -euo pipefail

# -------------------------------[ Globals ]---------------------------------- #
INSTALL_DIR="/var/www/pterodactyl"
LOG_FILE="/var/log/blueprint-installer.log"
NODE_SOURCE_LIST="/etc/apt/sources.list.d/nodesource.list"
NODE_KEYRING="/etc/apt/keyrings/nodesource.gpg"
BLUEPRINT_RELEASE_API="https://api.github.com/repos/BlueprintFramework/framework/releases/latest"

# Colors (guldkage-like UX)
RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"; BLUE="\e[34m"; BOLD="\e[1m"; END="\e[0m"

# -------------------------------[ Helpers ]---------------------------------- #
log()   { echo -e "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }
ok()    { echo -e "${GREEN}[OK]${END} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${END} $*"; }
err()   { echo -e "${RED}[ERROR]${END} $*" >&2; }
step()  { echo -e "${BLUE}${BOLD}==>${END} ${BOLD}$*${END}"; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    err "Debes ejecutar este script como root (sudo)."
    exit 1
  fi
}

detect_distro() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_VERSION_ID="${VERSION_ID:-}"
  else
    DISTRO_ID="unknown"
  fi
  case "$DISTRO_ID" in
    debian|ubuntu) ok "Distro detectada: $DISTRO_ID $DISTRO_VERSION_ID";;
    *) warn "Distro no probada: $DISTRO_ID. Intentaré continuar."; sleep 1;;
  esac
}

update_apt_quiet() { DEBIAN_FRONTEND=noninteractive apt-get update -y >>"$LOG_FILE" 2>&1; }

apt_install() {
  DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" >>"$LOG_FILE" 2>&1
}

ensure_tools() {
  step "Instalando dependencias base (ca-certificates, curl, gnupg, zip/unzip, git, wget, jq)..."
  update_apt_quiet
  apt_install ca-certificates curl gnupg zip unzip git wget jq
  ok "Dependencias base listas."
}

install_node20_yarn() {
  step "Instalando Node.js 20 y Yarn (vía NodeSource + npm)..."
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o "$NODE_KEYRING"
  echo "deb [signed-by=$NODE_KEYRING] https://deb.nodesource.com/node_20.x nodistro main" \
    > "$NODE_SOURCE_LIST"
  update_apt_quiet
  apt_install nodejs
  npm i -g yarn >>"$LOG_FILE" 2>&1
  ok "Node.js $(node -v) y Yarn $(yarn -v) instalados."
}

prepare_dir() {
  step "Preparando directorio ${INSTALL_DIR}..."
  mkdir -p "$INSTALL_DIR"
  chown -R www-data:www-data "$INSTALL_DIR" || true
  ok "Directorio preparado."
}

download_blueprint_release() {
  step "Descargando la última release de Blueprint (GitHub API)..."
  local url
  # Preferimos jq para extraer el primer asset browser_download_url
  url="$(curl -s "$BLUEPRINT_RELEASE_API" | jq -r '.assets[0].browser_download_url')"
  if [[ -z "$url" || "$url" == "null" ]]; then
    # Fallback grep/cut si no hay assets en la posición 0
    url="$(curl -s "$BLUEPRINT_RELEASE_API" | grep 'browser_download_url' | head -n1 | cut -d '"' -f 4)"
  fi
  if [[ -z "$url" ]]; then
    err "No se pudo obtener la URL de descarga de Blueprint."
    exit 1
  fi
  wget -qO "${INSTALL_DIR}/release.zip" "$url"
  ok "Release descargada en ${INSTALL_DIR}/release.zip"
}

unpack_and_seed() {
  step "Descomprimiendo release.zip en ${INSTALL_DIR}..."
  (cd "$INSTALL_DIR" && unzip -o release.zip >>"$LOG_FILE" 2>&1)
  ok "Descompresión finalizada."

  step "Creando .blueprintrc..."
  cat > "${INSTALL_DIR}/.blueprintrc" <<'RC'
WEBUSER="www-data";
OWNERSHIP="www-data:www-data";
USERSHELL="/bin/bash";
RC
  ok ".blueprintrc creado."
}

yarn_install_if_package() {
  step "Instalando dependencias con Yarn si existe package.json..."
  if [[ -f "${INSTALL_DIR}/package.json" ]]; then
    (cd "$INSTALL_DIR" && yarn install >>"$LOG_FILE" 2>&1)
    ok "Dependencias instaladas."
  else
    warn "No se encontró package.json; se omite yarn install."
  fi
}

run_blueprint_script() {
  step "Ejecutando blueprint.sh..."
  if [[ ! -x "${INSTALL_DIR}/blueprint.sh" && -f "${INSTALL_DIR}/blueprint.sh" ]]; then
    chmod +x "${INSTALL_DIR}/blueprint.sh"
  fi
  if [[ -x "${INSTALL_DIR}/blueprint.sh" ]]; then
    (cd "$INSTALL_DIR" && bash ./blueprint.sh | tee -a "$LOG_FILE")
    ok "blueprint.sh ejecutado."
  else
    err "No se encontró blueprint.sh ejecutable en ${INSTALL_DIR}."
    exit 1
  fi
}

# -------------------------------[ Actions ]---------------------------------- #
action_install_or_update() {
  require_root
  detect_distro
  ensure_tools
  install_node20_yarn
  prepare_dir
  download_blueprint_release
  unpack_and_seed
  yarn_install_if_package
  ok "Instalación/actualización completada. Recomendado ejecutar: 'Ejecutar blueprint.sh' en el menú."
}

action_execute() {
  require_root
  run_blueprint_script
}

action_cleanup() {
  require_root
  step "Limpieza de archivos temporales y fuentes NodeSource..."
  rm -f "${INSTALL_DIR}/release.zip" || true
  # Si quieres retirar NodeSource, descomenta:
  # rm -f "$NODE_SOURCE_LIST" "$NODE_KEYRING" || true
  # apt-get update -y >>"$LOG_FILE" 2>&1
  ok "Limpieza realizada."
}

action_uninstall_all() {
  require_root
  step "Desinstalando Blueprint del directorio ${INSTALL_DIR} (no toca Pterodactyl panel)..."
  if [[ -d "$INSTALL_DIR" ]]; then
    # Preserva el panel si lo estás usando; aquí sólo removemos artefactos de Blueprint.
    rm -f "${INSTALL_DIR}/release.zip" "${INSTALL_DIR}/.blueprintrc" || true
    find "$INSTALL_DIR" -maxdepth 1 -name "blueprint.sh" -exec rm -f {} \; || true
    ok "Artefactos de Blueprint removidos. Revisa manualmente si deseas limpiar más."
  else
    warn "Ruta no existe, nada que desinstalar."
  fi
}

# -------------------------------[ Menu UI ]---------------------------------- #
show_menu() {
  clear
  echo -e "${BOLD}Blueprint Installer (estilo guldkage)${END}"
  echo "Logs: $LOG_FILE"
  echo
  echo "  1) Instalar/Actualizar Blueprint"
  echo "  2) Ejecutar blueprint.sh"
  echo "  3) Limpieza (release.zip, etc.)"
  echo "  4) Desinstalar artefactos de Blueprint"
  echo "  0) Salir"
  echo
  read -rp "Selecciona una opción: " opt
  case "$opt" in
    1) action_install_or_update ;;
    2) action_execute ;;
    3) action_cleanup ;;
    4) action_uninstall_all ;;
    0) exit 0 ;;
    *) err "Opción inválida"; sleep 1 ;;
  esac
  echo
  read -rp "Pulsa ENTER para volver al menú..." _
}

# -------------------------------[ Main ]------------------------------------- #
touch "$LOG_FILE" >/dev/null 2>&1 || true
while true; do show_menu; done
