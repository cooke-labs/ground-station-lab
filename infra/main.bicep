targetScope = 'subscription'

@description('Region for the dedicated lab resource group and network.')
param location string = 'westus2'

@description('Dedicated resource group for all lab resources.')
param resourceGroupName string = 'rg-ground-station-lab'

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
