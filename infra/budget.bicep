targetScope = 'resourceGroup'

@description('Maximum monthly cost for this dedicated lab resource group, in USD.')
@minValue(1)
param amount int = 150

@description('First day of the current month, YYYY-MM-DD.')
param startDate string

@description('First day of the next month, YYYY-MM-DD.')
param endDate string

@secure()
@description('Email address of the lab owner for cost alerts. Pass at deployment; do not commit it.')
param contactEmail string

resource budget 'Microsoft.Consumption/budgets@2024-08-01' = {
  name: 'gsdl-cost-budget'
  properties: {
    category: 'Cost'
    amount: amount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: startDate
      endDate: endDate
    }
    notifications: {
      halfBudget: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 50
        thresholdType: 'Actual'
        contactEmails: [
          contactEmail
        ]
        contactGroups: []
        contactRoles: []
      }
      eightyPercent: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 80
        thresholdType: 'Actual'
        contactEmails: [
          contactEmail
        ]
        contactGroups: []
        contactRoles: []
      }
    }
  }
}
