# Gentoo ARM64 / systemd — Channel experimental

Experimental ARM64 rootfs builder using the shared Channel mainline kernel checkpoint.

- Rootfs label: `gentoo`
- Rootfs UUID: `89530000-6320-4000-8000-000000000001`
- Boot locator: existing Android `userdata` PARTUUID from `boot-channel.img`.
- Reuses a live kernel artifact when possible; otherwise builds the kernel only for this run.

Imagem desta branch: `gentoo-channel-rootfs.ext4.zst` (artefato `channel-gentoo-rootfs`).

---

## Ext4 raw e Android sparse: verificar e gravar

**Somente a imagem `gentoo`.** Extraia o ZIP do artefato GitHub e execute no **computador**:

~~~sh
zstd -d -k gentoo-channel-rootfs.ext4.zst
file gentoo-channel-rootfs.ext4
~~~

Se `file` indicar **ext4 raw**, converta para sparse se necessário:

~~~sh
img2simg gentoo-channel-rootfs.ext4 gentoo-sparse.img
fastboot flash userdata gentoo-sparse.img
~~~

Se já for **Android sparse**, não converta novamente: `fastboot flash userdata gentoo-channel-rootfs.ext4`. Alguns fastboots também gravam diretamente o ext4 raw: `fastboot flash userdata gentoo-channel-rootfs.ext4`. Para transformar sparse em raw no computador: `simg2img gentoo-sparse.img gentoo-extraido.ext4` (em Debian/Ubuntu, pacote `android-sdk-libsparse-utils`).

**O flash substitui os dados existentes em `userdata`.** Faça backup e confirme o destino. Sparse é formato de transporte e não expande o filesystem.

---

## Expandir o ext4 do `/` para a partição

Depois do primeiro boot, no **telefone**, como root, identifique origem, tipo e espaço:

~~~sh
findmnt -n -o SOURCE,FSTYPE /
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
df -h /
~~~

**Apenas se `/` for ext4 e a partição root estiver corretamente identificada**, use o dispositivo real no lugar do marcador:

~~~sh
resize2fs /dev/PARTICAO_ROOT_CONFIRMADA
df -h /
~~~

`resize2fs` sem tamanho cresce até o limite da partição, quando o kernel suporta redimensionamento online. Não execute `e2fsck` no `/` montado. Se faltar a ferramenta ou falhar online, use recuperação com ext4 desmontado e backup. A expansão não altera a tabela de partições.
