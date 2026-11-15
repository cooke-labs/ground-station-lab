targetScope = 'resourceGroup'

@description('Region of the existing lab virtual network.')
param location string = resourceGroup().location

@secure()
@description('SSH public key for emergency recovery. No inbound SSH rule is created.')
param sshPublicKey string

@description('Pinned, NVMe-capable Canonical Ubuntu 24.04 server image version.')
param imageVersion string = '24.04.202610250'

@description('Non-root Linux account for recovery and guest administration.')
param adminUsername string = 'laboperator'

@description('Daily auto-shutdown time in Pacific time, HHmm.')
param shutdownTime string = '0300'

var vmNames = [
  'gsdl-sim-vm'
  'gsdl-ground-vm'
]

var subnetNames = [
  'telemetry-sim'
  'ground-rx'
]

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: 'gsdl-vnet'
}

resource subnets 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = [for subnetName in subnetNames: {
  parent: vnet
  name: subnetName
}]

resource publicIps 'Microsoft.Network/publicIPAddresses@2024-05-01' = [for i in range(0, 2): {
  name: '${vmNames[i]}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}]

resource nics 'Microsoft.Network/networkInterfaces@2024-05-01' = [for i in range(0, 2): {
  name: '${vmNames[i]}-nic'
  location: location
  properties: {
    enableAcceleratedNetworking: true
    ipConfigurations: [
      {
        name: 'primary'
        properties: {
          primary: true
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnets[i].id
          }
          publicIPAddress: {
            id: publicIps[i].id
          }
        }
      }
    ]
  }
}]

resource vms 'Microsoft.Compute/virtualMachines@2024-07-01' = [for i in range(0, 2): {
  name: vmNames[i]
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2as_v6'
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: imageVersion
      }
      diskControllerType: 'NVMe'
      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: 32
        deleteOption: 'Delete'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    osProfile: {
      computerName: vmNames[i]
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nics[i].id
          properties: {
            primary: true
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}]

resource shutdownSchedules 'Microsoft.DevTestLab/schedules@2018-09-15' = [for i in range(0, 2): {
  name: 'shutdown-computevm-${vmNames[i]}'
  location: location
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    targetResourceId: vms[i].id
    dailyRecurrence: {
      time: shutdownTime
    }
    timeZoneId: 'Pacific Standard Time'
    notificationSettings: {
      status: 'Disabled'
      timeInMinutes: 30
    }
  }
}]
