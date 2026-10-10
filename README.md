# Experimental Channel Builds — Moto G7 Play

Matriz **experimental** de rootfs ARM64 para o Motorola Moto G7 Play (`channel`, SDM632). Esta `main` centraliza os workflows que executam builds das branches de distribuição; **não** compila rootfs do Moto G5S Plus/Sanders.

## Kernel comum e modelo de boot

- Kernel: [SaaSD3v/linux](https://github.com/SaaSD3v/linux), branch `msm8953/latest`.
- Workflow na `main`: **Build mainline kernel** (`.github/workflows/build-mainline.yml`).
- Checkpoint: `channel-mainline-kernel-<sha>`, contendo `boot-channel.img`, `sdm632-motorola-channel.dtb`, módulos, configuração e hashes.
- O boot é **direto, sem initramfs**, com o rootfs na partição Android `userdata`:

```text
root=PARTUUID=76dbdefa-f243-cd22-5da5-9374e6ad318b rootfstype=ext4 rootwait rw
```

As imagens ext4 das distribuições usam UUID `89530000-6320-4000-8000-000000000001`; o **label ext4 é próprio de cada distro**. PARTUUID GPT e UUID ext4 são identificadores diferentes. Confira a partição real antes de gravar qualquer imagem.

## Distribuições e workflows da matriz

| Branch | Distribuição / init | Workflow | Artefato |
| --- | --- | --- | --- |
| `debian` | Debian 13 / systemd | `debian.yml` | `channel-debian-rootfs` |
| `ubuntu` | Ubuntu 26.04.1 / systemd | `ubuntu.yml` | `channel-ubuntu-rootfs` |
| `alpine` | Alpine 3.24 / OpenRC | `alpine.yml` | `channel-alpine-rootfs` |
| `arch` | Arch Linux ARM / systemd | `arch.yml` | `channel-arch-rootfs` |
| `fedora` | Fedora 44 / systemd | `fedora.yml` | `channel-fedora-rootfs` |
| `gentoo` | Gentoo ARM64 / systemd | `gentoo.yml` | `channel-gentoo-rootfs` |
| `opensuse` | openSUSE Tumbleweed / systemd | `opensuse.yml` | `channel-opensuse-rootfs` |
| `void` | Void Linux ARM64 / runit | `void.yml` | `channel-void-rootfs` |
| `chimera` | Chimera Linux ARM64 / dinit | `chimera.yml` | `channel-chimera-rootfs` |
| `crux` | CRUX-ARM 3.8 / BSD-style rc | `crux.yml` | `channel-crux-rootfs` |

**Status:** experimentais; a existência de um workflow/artifact não confirma inicialização ou Wi-Fi no aparelho. Cada branch de distro tem seu próprio `build.sh`, overlay e YAML; as cópias na `main` existem para disponibilizar **Run workflow**.

## Como construir e baixar um rootfs

1. Em **Actions**, execute **Build mainline kernel** se precisar gerar o checkpoint base.
2. Selecione o workflow da distribuição desejada e clique **Run workflow** na `main`.
3. `reuse_kernel` permite reaproveitar o checkpoint. `kernel_run_id` seleciona uma execução específica, quando necessário. Sem checkpoint disponível, o workflow pode compilar kernel temporário apenas para instalar os módulos corretos.
4. Baixe o artefato da distribuição e confira `build-info.txt` e checksums. O rootfs gerado é normalmente `<distro>-channel-rootfs.ext4.zst`.

Exemplo **no computador**, usando a imagem CRUX:

```sh
zstd -d -k crux-channel-rootfs.ext4.zst
```

Nunca misture rootfs de uma distribuição com módulos de uma compilação incompatível do kernel.

## USB RNDIS e acesso SSH

As imagens foram preparadas para gerenciamento por USB: IP do telefone `172.16.42.1/24`, com acesso root no modo fixo `ssh_auth=ssh`, sem seletor de senha ou chave no dispatch.

Do **computador conectado por USB**:

```sh
ssh root@172.16.42.1
```

Esse acesso de desenvolvimento concede root total a um host USB. Não conecte a equipamentos não confiáveis. O fato de o SSH escutar em `172.16.42.1` não basta para provar isolamento da rede Wi-Fi; valide no hardware.

## Wi-Fi e Internet nas distribuições com NetworkManager

Os builds **Debian, Ubuntu, Alpine, Arch, Fedora, Gentoo, openSUSE, Void e Chimera** declaram NetworkManager. O comando `nmcli` só funcionará se o pacote, seu serviço e a interface `wlan0` estiverem realmente disponíveis na imagem iniciada. Os gestores de serviços variam (systemd, OpenRC, runit, dinit).

No **terminal do telefone**, quando `nmcli` estiver instalado:

```sh
command -v nmcli
nmcli general status
nmcli device status
nmcli radio wifi on

# Escanear redes e consultar sinal
nmcli device wifi rescan ifname wlan0
nmcli -f IN-USE,SSID,SIGNAL,SECURITY device wifi list ifname wlan0

# Conectar solicitando a senha (evita registrá-la na linha de comando)
nmcli --ask device wifi connect "NOME_DA_REDE" ifname wlan0

# Verificar endereços e Internet
nmcli connection show --active
ip -4 address show dev wlan0
ip route
getent hosts example.org
ping -c 3 1.1.1.1
```

Também existe `nmcli device wifi connect "SSID" password "SENHA" ifname wlan0`, mas a senha pode ficar no histórico. Para usar uma conexão salva: `nmcli connection up "NOME_DA_CONEXAO"`. Não suponha que todos os ambientes tenham `systemctl`: Alpine usa OpenRC, Void usa runit e Chimera usa dinit.

## CRUX-ARM 3.8: diferença importante

**CRUX não recebe NetworkManager nem `nmcli` automaticamente neste builder.** O script monta uma base minimalista, prepara serviços BSD-style rc, configura USB RNDIS e compila/inclui `dnsmasq` para o DHCP USB. Se o computador não adquirir IP no USB, pode ser necessário definir manualmente um endereço do host, como `172.16.42.2/24`, nessa interface.

No CRUX, confirme os componentes antes de tentar os comandos destinados às outras distros:

```sh
ip -br link
ip -br addr
command -v nmcli || echo "NetworkManager nao instalado neste rootfs"
command -v iw
```

Se você **instalar NetworkManager posteriormente**, poderá usar os comandos `nmcli` da seção anterior **após configurá-lo e iniciar o serviço conforme o CRUX**. Essa instalação é responsabilidade do sistema já iniciado, não do builder experimental. A presença de `wlan0` e firmware também precisa ser confirmada. Evite assumir que o comando de varredura Wi-Fi existirá antes de instalar as ferramentas necessárias.

## Data e hora UTC — configuração manual temporária

Os scripts desta matriz não adicionam uma configuração própria de NTP/Chrony/Timesyncd. Alguns sistemas-base podem trazer configurações suas; o projeto não garante ausência total desses pacotes. `TZ` muda a exibição do fuso, **não** ajusta um relógio parado em 1970. Hora errada pode quebrar certificados HTTPS e gerenciadores de pacotes, sobretudo no primeiro boot.

No **telefone**, com privilégios de root, substitua o horário do exemplo pela **data/hora UTC correta**:

```sh
date -u
date -u -s "2026-10-10 12:00:00"   # EXEMPLO; use o UTC atual
date -u
date
```

O ajuste é provisório e não é sincronização automática; com RTC inadequado, talvez seja necessário repeti-lo após reinicialização. `TZ=America/Porto_Velho date` só altera a apresentação quando os dados do fuso estão disponíveis.
