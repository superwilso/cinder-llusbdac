#!/bin/sh
# Build llusbdac.ko for the NW-A50 series from public sources, every one pinned by hash:
#
#   - llusbdac itself: zhangboyang/llusbdac at UPSTREAM_COMMIT (GPLv2), unmodified.
#   - The kernel it builds against: Sony's GPL release of linux-kernel-3.10.26 for the NW-A57
#     (the NW-A50 series' kernel), configured with BBDMP5_linux_debug_defconfig, the A50 series'
#     own config in that tree.
#   - GCC 4.9.3 for ARM, from Ubuntu 16.04's packages. Linux 3.10 predates GCC 5, and the
#     player's own modules were built with GCC 4.8; the module's vermagic must read
#     "3.10.26 SMP preempt mod_unload ARMv7", as theirs does.
#
# Needs: curl, git, make, a host gcc, dpkg-deb, and ARM binutils (binutils-arm-linux-gnueabihf).
# Output: out/llusbdac.ko and out/llusbdac.ko.sha256.
set -eu

UPSTREAM=https://github.com/zhangboyang/llusbdac
UPSTREAM_COMMIT=eeb31d53310c9cbf159f84a18de493cd2c31fcfc

KERNEL_URL=https://prodgpl.blob.core.windows.net/download/Audio/NW-A57/linux-kernel-3.10.26.tar.gz
KERNEL_SHA=3aef2bdcc4ecd43ab9fed0f038fa384e2515c58851573908dc8b1743febb1609
DEFCONFIG=BBDMP5_linux_debug_defconfig

POOL=http://archive.ubuntu.com/ubuntu/pool
DEBS="
universe/g/gcc-4.9-cross/gcc-4.9-arm-linux-gnueabihf_4.9.3-13ubuntu2cross1_amd64.deb 920d07f97bdba8703aa4e2162ae8cab03110409435fbdf3a574e6f27bf9bd4b0
universe/g/gcc-4.9-cross/gcc-4.9-arm-linux-gnueabihf-base_4.9.3-13ubuntu2cross1_amd64.deb 5f7cb56ee634d3cf62400683f5d00162eff5605cbdf1ba0281e404ddac8a2c9e
universe/g/gcc-4.9-cross/cpp-4.9-arm-linux-gnueabihf_4.9.3-13ubuntu2cross1_amd64.deb 8dbd377e413e993b0f0f4e6218b957bdcac8bdbe2fa4a04ecedcfc36b53f1ea0
universe/g/gcc-4.9-cross/libgcc-4.9-dev-armhf-cross_4.9.3-13ubuntu2cross1_all.deb 48ae26ea9c44bca5484f4fe989a01259cc1d871966d58ca3db74cfb23c65b45b
main/i/isl/libisl15_0.16.1-1_amd64.deb 842d832c28ded8725303ef42e81ff3b190371ab1f0617196a5290adf91e3a60d
main/m/mpfr4/libmpfr4_3.1.4-1_amd64.deb 3973a97387bbe0e8a775995c22861d8478edee2a594e8117970f635de25b2c8a
"

HERE=$(cd "$(dirname "$0")" && pwd)
W=$HERE/work
mkdir -p "$W/debs" "$HERE/out"

# fetch URL FILE SHA: download unless a file with that hash is already there.
fetch() {
    if ! echo "$3  $2" | sha256sum -c --status 2>/dev/null; then
        curl -fsSL --retry 3 -o "$2" "$1"
        echo "$3  $2" | sha256sum -c
    fi
}

echo "== toolchain"
echo "$DEBS" | while read -r path sha; do
    [ -n "$path" ] || continue
    fetch "$POOL/$path" "$W/debs/$(basename "$path")" "$sha"
done
rm -rf "$W/tc" && mkdir -p "$W/tc" "$W/bin"
for d in "$W"/debs/*.deb; do dpkg-deb -x "$d" "$W/tc"; done
# The packaged gcc looks for its assembler where Ubuntu installed it; point it at the host's ARM
# binutils, and at the old host libraries it was linked against.
cat > "$W/bin/arm-linux-gnueabihf-gcc" <<GCC
#!/bin/sh
LD_LIBRARY_PATH=$W/tc/usr/lib/x86_64-linux-gnu exec $W/tc/usr/bin/arm-linux-gnueabihf-gcc-4.9 -B/usr/arm-linux-gnueabihf/bin/ "\$@"
GCC
chmod +x "$W/bin/arm-linux-gnueabihf-gcc"
for t in ld as ar nm objcopy objdump strip readelf; do
    ln -sf "/usr/bin/arm-linux-gnueabihf-$t" "$W/bin/arm-linux-gnueabihf-$t"
done
PATH=$W/bin:$PATH
export PATH
arm-linux-gnueabihf-gcc --version | head -1

echo "== kernel"
fetch "$KERNEL_URL" "$W/linux-kernel-3.10.26.tar.gz" "$KERNEL_SHA"
if [ ! -f "$W/kernel/.prepared" ]; then
    rm -rf "$W/kernel" && mkdir -p "$W/kernel"
    tar xzf "$W/linux-kernel-3.10.26.tar.gz" -C "$W/kernel"
    cp "$W/kernel/arch/arm/configs/$DEFCONFIG" "$W/kernel/.config"
    K="make -C $W/kernel ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-"
    $K olddefconfig >/dev/null
    $K prepare >/dev/null
    $K scripts >/dev/null
    touch "$W/kernel/.prepared"
fi

echo "== llusbdac $UPSTREAM_COMMIT"
rm -rf "$W/llusbdac"
git clone -q "$UPSTREAM" "$W/llusbdac"
git -C "$W/llusbdac" -c advice.detachedHead=false checkout -q "$UPSTREAM_COMMIT"
for p in "$HERE"/patches/*.patch; do
    [ -f "$p" ] || continue
    echo "applying $(basename "$p")"
    git -C "$W/llusbdac" apply "$p"
done
make -C "$W/kernel" M="$W/llusbdac/llusbdac" ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- modules
arm-linux-gnueabihf-strip -g "$W/llusbdac/llusbdac/llusbdac.ko"

cp "$W/llusbdac/llusbdac/llusbdac.ko" "$HERE/out/llusbdac.ko"
(cd "$HERE/out" && sha256sum llusbdac.ko > llusbdac.ko.sha256)
magic=$(strings -a "$HERE/out/llusbdac.ko" | grep '^vermagic=')
echo "$magic"
case "$magic" in
    "vermagic=3.10.26 SMP preempt mod_unload ARMv7"*) ;;
    *)
        echo "vermagic does not match the player's modules" >&2
        exit 1
        ;;
esac
cat "$HERE/out/llusbdac.ko.sha256"
