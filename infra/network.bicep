targetScope = 'resourceGroup'

@description('Prefix for the lab virtual network and network security group names.')
param namePrefix string = 'gsdl'

@description('Azure region for the network resources.')
param location string = resourceGroup().location

var simSubnetName = 'telemetry-sim'
var simSubnetPrefix = '10.42.10.0/24'
var groundSubnetName = 'ground-rx'
var groundSubnetPrefix = '10.42.20.0/24'

resource simNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${namePrefix}-sim-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'DenyGroundToSim'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: groundSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: simSubnetPrefix
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource groundNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${namePrefix}-ground-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSimTelemetry'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Udp'
          sourceAddressPrefix: simSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: groundSubnetPrefix
          destinationPortRange: '5514'
        }
      }
      {
        name: 'DenyOtherSimToGround'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: simSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: groundSubnetPrefix
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: '${namePrefix}-vnet'
  location: location
  properties: {
    privateEndpointVNetPolicies: 'Disabled'
    addressSpace: {
      addressPrefixes: [
        '10.42.0.0/16'
      ]
    }
    subnets: [
      {
        name: simSubnetName
        properties: {
          addressPrefix: simSubnetPrefix
          defaultOutboundAccess: false
          networkSecurityGroup: {
            id: simNsg.id
          }
        }
      }
      {
        name: groundSubnetName
        properties: {
          addressPrefix: groundSubnetPrefix
          defaultOutboundAccess: false
          networkSecurityGroup: {
            id: groundNsg.id
          }
        }
      }
    ]
  }
}

output simSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, simSubnetName)
output groundSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, groundSubnetName)
