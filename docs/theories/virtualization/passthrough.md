# Hardware passthrough

The concept of hardware passthrough is directly passing the hardware devices to virtual machines, bypassing hypervisor or emulation layers. virtual machines can access to physical hardware directly.

## GRUB

GRUB (Grand Unified Bootloader) is bootloader for OS. They runs first when the computer boots, load the kernel on memory, and binds hardwares on kernel with their driver. The configuration of sequence that GRUB decides is stored on initramfs.

## IOMMU

IOMMU is MMU (Memory Management Unit) for I/O device. It convert and isolate logical address of IO devices to physical address of memory, so that I/O device's DMA (Direct Memory Access). When IOMMU is enabled on GRUB, they can allocate and manage hardwares address on physical memory. This fact allows, this can reserve physical address area for device to allocate virtual machines.

## VFIO

vfio is driver that the devices which is allocated on virtual machines. vfio driver prevents access from hypervisor OS, so that only virtual machine which has that device can access to the hardware.
