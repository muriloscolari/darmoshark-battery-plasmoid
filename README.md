# Darmoshark Battery — KDE Plasma 6 Widget

Um widget minimalista para **KDE Plasma 6** que exibe **apenas o ícone do mouse e a porcentagem da bateria** diretamente no painel/barra (ex.: `🖱️ 54%`), sem a poluição visual do applet completo de energia do KDE.

Funciona com **todos os mouses Darmoshark** expostos pelo módulo de kernel `darmoshark-battery` em `/sys/class/power_supply/darmoshark_battery_*`:

| USB ID | Dispositivo |
|---|---|
| `1915:073c` | Darmoshark M3S Pro (cabo) |
| `1915:0723` | Darmoshark M3S Pro (2.4 GHz, receptor 1K NRF) |
| `248a:ff12` | Darmoshark M3 (cabo) |
| `248a:ff18` | Darmoshark M3S (cabo) |
| `248a:ff10` | Darmoshark N3 (cabo) |
| `248a:ff30` | Darmoshark M3 / M3S / N3 (2.4 GHz, receptor 1K Telink) |
| `248a:ff31` | Darmoshark M3 / M3S / N3 (2.4 GHz, receptor 2K Telink) |

---

## Pré-requisito obrigatório: módulo kernel `darmoshark-battery`

Este plasmoid **não** fala diretamente com o hardware USB — ele lê a interface padrão `/sys/class/power_supply/darmoshark_battery_*` criada pelo driver [`ayasaki-exs/darmoshark-battery`](https://github.com/ayasaki-exs/darmoshark-battery).

Antes (ou durante) a instalação do widget, você precisa instalar o driver:

### Opção A — Arch Linux (AUR)

> **Nota:** caso o suporte aos modelos Telink (`248a:*` — M3, M3S, N3) ainda não tenha sido integrado ao repositório principal, use a Opção B (branch `feat/telink-248a-support`).

```sh
yay -S darmoshark-battery-dkms-git
# ou: paru -S darmoshark-battery-dkms-git
sudo modprobe darmoshark_battery
```

### Opção B — Compilar da source (DKMS)

Requer `dkms`, `git`, ferramentas de compilação (`base-devel` / `build-essential`) e os headers do kernel (`linux-headers`).

```sh
# Repositório original (M3S Pro):
git clone https://github.com/ayasaki-exs/darmoshark-battery.git

# Ou fork com suporte ao Darmoshark M3 / M3S / N3 (Telink 248a):
git clone -b feat/telink-248a-support https://github.com/muriloscolari/darmoshark-battery.git

cd darmoshark-battery
make test
sudo dkms add .
sudo dkms build darmoshark-battery/0.1.0
sudo dkms install darmoshark-battery/0.1.0
sudo modprobe darmoshark_battery
printf 'darmoshark_battery\n' | sudo tee /etc/modules-load.d/darmoshark-battery.conf
```

Verifique se a bateria já aparece no sistema:

```sh
cat /sys/class/power_supply/darmoshark_battery_0/{model_name,capacity}
```

---

## Instalação do Widget

```sh
git clone https://github.com/muriloscolari/darmoshark-battery-plasmoid.git
cd darmoshark-battery-plasmoid
./install.sh
```

O script `./install.sh`:
1. Verifica se o módulo `darmoshark_battery` já está instalado (e oferece instalá-lo via AUR ou DKMS caso não esteja).
2. Instala o plasmoid `me.muriloscolari.darmoshark` em `~/.local/share/plasma/plasmoids/`.

Você também pode automatizar pelas flags:
```sh
./install.sh --skip-driver --restart   # instala apenas o widget e reinicia o plasmashell
./install.sh --with-aur                # instala o driver via AUR + widget
./install.sh --with-source             # compila e instala o driver via DKMS + widget
```

### Como adicionar ao painel do KDE
1. Clique com o botão direito na barra/painel do KDE e escolha **Adicionar ou gerenciar widgets...**.
2. Procure por **Darmoshark Battery** e arraste-o para a posição desejada no painel.
3. *(Opcional)* Para esconder o ícone nativo de **Energia e Bateria** da bandeja do sistema: botão direito na setinha da área de notificações → **Configurar Área de Notificações...** → **Entradas** → mude *Energia e Bateria* para **Sempre oculto**.

---

## Funcionalidades

- Exibe apenas ícone do mouse + porcentagem (`54%`) direto no painel, sem popups extras.
- Atualiza automaticamente a cada 15 segundos (e imediatamente ao clicar no widget).
- Muda a cor de alerta para laranja (`<= 25%`) e vermelho (`<= 15%`).
- Tooltip ao passar o mouse mostra o modelo detectado (e lista todos os dispositivos conectados caso haja mais de um `darmoshark_battery_*`).

---

## Desinstalação

```sh
./uninstall.sh
```

---

## Licença

GPL-2.0-or-later. Veja [LICENSE](LICENSE).
