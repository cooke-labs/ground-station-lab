targetScope = 'subscription'

@description('Region for the dedicated lab resource group and network.')
param location string = 'westus2'

@description('Dedicated resource group for all lab resources.')
param resourceGroupName string = 'rg-ground-station-lab'

@description('Opt in to paid VM resources; false keeps this deployment network-only.')
param deployCompute bool = false

@secure()
@description('SSH public key for recovery. Required when deployCompute is true.')
param sshPublicKey string = ''

resource labGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: resourceGroupName
  location: location
  tags: {
    project: 'ground-station-lab'
  }
}

module network './network.bicep' = {
  name: 'network-foundation'
  scope: labGroup
  params: {
    namePrefix: 'gsdl'
    location: location
  }
}

module compute './compute.bicep' = if (deployCompute) {
  name: 'compute-foundation'
  scope: labGroup
  params: {
    location: location
    sshPublicKey: sshPublicKey
  }
  dependsOn: [network]
}
