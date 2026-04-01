# Firmware installation

Cloud-init has no firmware in it, so i915 driver is needed to install.

When the app node is initiated by ansible, `firmware-intel-graphics` and `intel-media-va-driver-non-free` are installed. And only when they are installed, `update-initramfs -u` and `reboot` modules run as a handler.

## Verification
After reboot, check the render device.
```bash
ls -l /dev/dri
# crw-rw---- 1 root video 226,   0 ... card0
# crw-rw---- 1 root render 226, 128 ... renderD128
