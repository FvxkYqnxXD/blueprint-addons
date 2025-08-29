#!/bin/bash

set -e  # Detiene el script si ocurre algún error

echo "🔧 Instalando dependencias básicas..."
apt-get update
apt-get install -y ca-certificates curl gnupg zip unzip git wget

echo "🔐 Configurando llaves de Nodesource..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

echo "📦 Añadiendo repositorio de Node.js 20..."
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" > /etc/apt/sources.list.d/nodesource.list

echo "🔄 Actualizando repositorios..."
apt-get update

echo "🚀 Instalando Node.js y Yarn..."
apt-get install -y nodejs
npm install -g yarn

echo "📁 Entrando al directorio de Pterodactyl..."
cd /var/www/pterodactyl

echo "📦 Instalando dependencias con Yarn..."
yarn

echo "📥 Descargando última versión del Blueprint Framework..."
latest_url=$(curl -s https://api.github.com/repos/BlueprintFramework/framework/releases/latest | grep 'browser_download_url' | cut -d '"' -f 4)
wget "$latest_url" -O release.zip

echo "📦 Moviendo archivo release.zip..."
mv release.zip /var/www/pterodactyl/release.zip

echo "📂 Descomprimiendo release.zip..."
unzip release.zip

echo "⚙️ Configurando archivo .blueprintrc..."
touch /var/www/pterodactyl/.blueprintrc
echo 'WEBUSER="www-data";
OWNERSHIP="www-data:www-data";
USERSHELL="/bin/bash";' >> /var/www/pterodactyl/.blueprintrc

echo "🚀 Ejecutando blueprint.sh..."
chmod +x blueprint.sh
bash blueprint.sh

echo "✅ Todo listo. Instalación y configuración completadas con éxito."
