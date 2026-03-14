# ADR 008 - passthrough

## Date

- Feb/23/2026
    - First documentation

## Status

- Accepted

## Context

- App VM needs GPU for heavy workloads like Immich \(hardware transcoding and machine learning\)
- App VM needs huge data storage for its own services 

## Considerations

### iGPU

- SR-IOV
    - SR-IOV is tech to divide PCIe devices for several VMs.
    - Current stable linux kernel doesn't support sr-iov
    - It is necessary to use DKMS for sr-iov
        - Use DKMS is unstable depending on kernel upgrade, and the most important thing in server is stability.
    - When passthrough iGPU itself, hypervisor cannot use graphic function.
        - All nodes are managed by SSH session, so it is not a problem.

### Storage

- Each HDD
    - Aoostar WTR Pro has their own sata controller for HDD.
    - It is more effective and advantageous to passthrough SATA controller itself to manage btrfs RAID10, and HDD health check via S.M.A.R.T values.

## Decisions

- Passthrough N150's iGPU to APP VM
- Passthrough SATA controller to APP VM

## Consequences

- Passthrough iGPU itself to APP vm.
- Passthrough SATA controller to APP vm.
