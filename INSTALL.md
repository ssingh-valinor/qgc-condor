# Install and Build

Ground Control Station for MAVLink vehicles. Linux x86_64.

Two install options are available: an AppImage (no install, runs anywhere) or a
Debian package (integrates with the system, recommended on Debian/Ubuntu).

## Install: Debian package

```sh
sudo apt install ./QGC-Condor_*_amd64.deb
```

The leading `./` is required. Without it, apt looks for a package by that name
in your configured repositories and fails.

The package is self-contained — Qt and GStreamer are bundled, so no Qt
installation is needed. It installs the desktop entry and icons, so the
application appears in your launcher with the correct icon and no extra steps.

If the package sits under your home directory, apt prints a note that the
download was performed unsandboxed because the `_apt` user could not read the
file. The install still succeeds. To avoid the note, stage the package somewhere
world-readable first:

```sh
cp QGC-Condor_*_amd64.deb /tmp/
sudo apt install /tmp/QGC-Condor_*_amd64.deb
```

Uninstall:

```sh
sudo apt remove qgc-condor
```

## Install: AppImage

```sh
chmod +x QGC-Condor-x86_64.AppImage
./QGC-Condor-x86_64.AppImage
```

The AppImage requires FUSE 2:

- Ubuntu 24.04 and newer: `sudo apt install libfuse2t64`
- Ubuntu 22.04 and older: `sudo apt install libfuse2`

If FUSE cannot be installed, run the bundle unpacked instead:

```sh
./QGC-Condor-x86_64.AppImage --appimage-extract-and-run
```

### Launcher icon

An AppImage is not visible to the desktop's application database, so the dock
and window list show a generic icon rather than the application's own. To
register it:

```sh
./QGC-Condor-x86_64.AppImage --desktop-icon y
```

This copies the desktop entry and icons into `~/.local/share`, pointing at the
AppImage's current location, and exits without launching. The application then
appears in the applications menu with the correct icon. Run it again after
moving or renaming the AppImage to repair the entry.

To undo:

```sh
./QGC-Condor-x86_64.AppImage --desktop-icon n
```

Already-running windows keep the icon they started with. Restart the
application after registering it.

## Serial port access

To connect over USB or serial, add yourself to the `dialout` group, then log out
and back in:

```sh
sudo usermod -aG dialout $USER
```

## Build from source

Docker is the only host requirement. The compiler, Qt, and GStreamer all live
inside the build image, so nothing else needs to be installed.

1. Install Docker and grant your user access:

   ```sh
   sudo apt install docker.io
   sudo usermod -aG docker $USER
   ```

   Log out and back in for the group change to take effect.

2. Clone the repository with its submodules:

   ```sh
   git clone --recursive https://github.com/ssingh-valinor/qgc-condor.git
   cd qgc-condor
   ```

   If you already cloned without `--recursive`:

   ```sh
   git submodule update --init --recursive
   ```

3. Build:

   ```sh
   ./deploy/docker/run-docker.sh ubuntu
   ```

Both packages are written to `build/`:

- `QGC-Condor-x86_64.AppImage`
- `QGC-Condor_<version>_amd64.deb`

The first run downloads the base image and compiles from scratch, which takes a
while. Later runs reuse the cached image and the existing `build/` directory, so
they are much faster.

### Other targets

```sh
./deploy/docker/run-docker.sh <variant> [build-type]
```

- Variants: `ubuntu`, `ubuntu-2204`, `ubuntu-2604`, `debian`, `fedora`, `arch`,
  `aarch64`, `android`
- Build types: `Release` (default), `Debug`, `RelWithDebInfo`, `MinSizeRel`

The `aarch64` variant cross-compiles and writes to `build-aarch64/` instead.
