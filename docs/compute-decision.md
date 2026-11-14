# Compute candidate and cost gate

Status: candidate selected for the next deployment preview. No VM has been provisioned.

## Why this size

The lab subscription's West US 2 SKU query listed `Standard_D2as_v6` without a location restriction. The `standardDav6Family` quota is 10 vCPUs with 0 used; the regional quota is also 10 with 0 used. Two VMs at 2 vCPUs each would use 4 vCPUs of both quotas. A listing and quota do not guarantee allocation at deployment time.

Earlier candidates were ruled out using subscription-specific evidence: `Standard_B2s` and several D v3/v4 sizes had `Location:NotAvailableForSubscription`; the listed B v2 and D v5 families had zero vCPU quota. This is why the template will use a checked candidate rather than assume a broadly advertised VM size is deployable.

Microsoft documents `Standard_D2as_v6` as 2 vCPUs, 8 GiB RAM, x86-64, Generation 2 only, with no local temporary disk. It requires an OS image that supports NVMe and accelerated networking. The next checkpoint must verify the exact Ubuntu image and network interface configuration before VM deployment. [Dasv6 size specifications](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/general-purpose/dasv6-series), [NVMe image requirements](https://learn.microsoft.com/en-us/azure/virtual-machines/nvme-overview)

## Cost boundary

Microsoft's public Retail Prices API returned a regular Linux consumption rate of **USD 0.0908 per VM-hour** for `Standard_D2as_v6` in `westus2` on 2026-11-13. Two VMs running continuously for five days would cost **USD 21.79 in compute** (`0.0908 × 2 × 120`, rounded). Deallocating them sooner reduces compute hours. This estimate excludes managed disks, public IPs, outbound data, Log Analytics, Sentinel, and any other service. Retail rates can differ from the subscription's effective billing rate. [Retail Prices API](https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices)

The project has a **USD 150 maximum over five days**. Before provisioning VMs, set a budget alert, define a shutdown schedule, and estimate the remaining components. A budget alert is a notification, not a spending cap. Keep all lab resources in the dedicated group for inventory and teardown; document any subscription-scoped exceptions. [Lifecycle commands](lifecycle.md)
