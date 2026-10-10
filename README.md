# Chimera Linux / dinit — Channel experimental

Experimental ARM64 rootfs branch.

- Rootfs label: `chimera`
- Fixed ext4 UUID: `89530000-6320-4000-8000-000000000001`
- Shared mainline kernel checkpoint/fallback model.
- Boot remains direct to Android `userdata` by PARTUUID; no initramfs.

Imagem desta branch: `chimera-channel-rootfs.ext4.zst` (artefato `channel-chimera-rootfs`).

---

## Preparar a imagem raw ou Android sparse

**Só para o rootfs `chimera`.** Depois de baixar e extrair o ZIP do artefato do GitHub Actions, no **computador**:

~~~sh
zstd -d -k chimera-channel-rootfs.ext4.zst
file chimera-channel-rootfs.ext4
~~~

Se `file` identificar **ext4 raw**, converta para Android sparse quando necessário:

~~~sh
img2simg chimera-channel-rootfs.ext4 chimera-sparse.img
fastboot flash userdata chimera-sparse.img
~~~

Se a imagem já for **Android sparse**, **não a converta outra vez**; use `fastboot flash userdata chimera-channel-rootfs.ext4`. Alguns fastboots também aceitam ext4 raw diretamente com `fastboot flash userdata chimera-channel-rootfs.ext4`. Para inspecionar um sparse como raw no computador: `simg2img chimera-sparse.img chimera-extraido.ext4` (no Debian/Ubuntu, ferramentas do pacote `android-sdk-libsparse-utils`).

**O flash de `userdata` apaga o conteúdo anterior.** Verifique a partição, a imagem de boot correspondente e os backups. Sparse não modifica o tamanho do filesystem.

---

## Expandir o filesystem ext4 do `/`

Após iniciar o Linux no **Moto G7 Play**, como root, confira primeiro a origem e o formato de `/`:

~~~sh
findmnt -n -o SOURCE,FSTYPE /
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
df -h /
~~~

**Somente se `/` for ext4 e a partição de root estiver comprovadamente correta**, substitua o marcador pelo dispositivo real:

~~~sh
resize2fs /dev/PARTICAO_ROOT_CONFIRMADA
df -h /
~~~

Sem tamanho, `resize2fs` pode expandir o ext4 até o espaço da partição existente (se o kernel suportar crescimento online). Não rode `e2fsck` em filesystem montado. Se o utilitário faltar ou a expansão online não for suportada, use recuperação com filesystem desmontado e backup. Não altere a tabela GPT apenas para expandir `/`.
