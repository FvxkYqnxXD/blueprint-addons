#!/bin/bash

# URL del archivo raw (no uses el enlace de edición)
FILE_URL="https://raw.githubusercontent.com/FvxkYqnxXD/blueprint-addons/main/blueprint-installer.sh"
LOCAL_FILE="blueprint-installer.sh"

# Descargar el archivo
curl -sSL "$FILE_URL" -o "$LOCAL_FILE"

# Verificar si se descargó correctamente
if [ -f "$LOCAL_FILE" ]; then
    chmod +x "$LOCAL_FILE"
    ./"$LOCAL_FILE"
else
    echo "Error: No se pudo descargar el archivo."
    exit 1
fi
