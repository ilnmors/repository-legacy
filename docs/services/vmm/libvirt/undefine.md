# Undefine VM

Undefine VM is critical to whole systme.

## process

```bash
# Shutdown VM
systemctl --user stop "$VM_NAME".service
## virsh stop|destroy "$VM_NAME"

# Undefien VM
virsh undefine "$VM_NAME" --nvram # All vms use uefi, so the option, `--nvram` is needed to remove nvram file

# Delete VM files
sudo rm -r /var/lib/libvirt/images/"$VM_NAME".qcow2
sudo rm -r /var/lib/libvirt/seeds/"$VM_NAME"_seed.iso
```
