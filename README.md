# cinder-llusbdac

[llusbdac](https://github.com/zhangboyang/llusbdac), the low-latency USB DAC kernel module by
zhangboyang, built for the Sony NW-A50 series (NW-A55, A56, A57) from public sources.

Stock USB DAC mode on these players adds a noticeable delay. llusbdac replaces the player's USB
audio function with its own: about 50 ms of latency, PCM only (no DSD), sound as with Direct Source
on, and a status screen showing the format and a checksum of what arrives. Upstream wrote it for
the NW-ZX300, which runs the same 3.10.26 kernel on the same MediaTek chip.

It is kept apart from [Cinder](https://github.com/superwilso/Cinder) because it is GPLv2 and
Cinder is not. Cinder's installer can download the module from this repo's releases as its
optional low-latency USB DAC component; a player without it keeps Sony's USB DAC.

## What is built, from what

`build.sh` builds `out/llusbdac.ko` from three public sources, each pinned by hash:

| Source | Pinned at |
|---|---|
| llusbdac (GPLv2), unmodified | upstream commit `eeb31d5` |
| Sony's GPL kernel source for the NW-A57 (`linux-kernel-3.10.26`), configured with `BBDMP5_linux_debug_defconfig`, the A50 series' config | sha256 `3aef2bdc…` |
| GCC 4.9.3 for ARM, from Ubuntu 16.04's packages (Linux 3.10 predates GCC 5) | sha256 per package |

The build checks that the module's `vermagic` reads `3.10.26 SMP preempt mod_unload ARMv7`, as
the player's own modules do. Any changes this repo needs to make to llusbdac will go in
`patches/` and be applied on top of the pinned commit; today there are none.

Releases are built by the workflow in `.github/workflows/build.yml`, never by hand, and each one
states the module's sha256.

## Build it yourself

On Ubuntu 22.04 or 24.04 (x86-64):

```sh
sudo apt-get install -y binutils-arm-linux-gnueabihf curl git make gcc
./build.sh
```

The first run downloads about 165 MB (the kernel source and the compiler).

## Status

Built, not yet run on an NW-A50 series player by this project. A kernel module runs with the
whole kernel's privileges: if it misbehaves, the player can freeze or restart. Upstream's notes
say the module stays loaded until the player restarts.

## Licence

GPLv2, as llusbdac. See `LICENSE`. The source for every released binary is the pinned commits and
archives named in `build.sh`, plus this repo.
