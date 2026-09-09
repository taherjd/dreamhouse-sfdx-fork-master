# Salesforce Fixtures — SI Practice Rules

A ready SFDX project with a matched fail and pass artefact for five rules that encode practice IP rather than general best practice.

## Option A · Scan the repository (easier for a demo)

```bash
git init && git add . && git commit -m "QC Rule Builder SI practice fixtures"
git remote add origin git@github.com:<your-org>/qc-rule-builder-si-fixtures.git
git push -u origin main
```

Connect the repository in the Quality Clouds portal. Nothing needs to compile, so the custom object references are irrelevant. For SI-3 in particular this is the more honest demonstration, because the whole point is that those objects are outside your scope.

## Option B · Deploy to an org

```bash
sf project deploy start --target-org <your-alias>
```

You would need `Invoice__c`, `Employee_Commission__c`, `GL_Posting__c`, `Opportunity_Won__e`, `Total_Contract_Value__c`, `Requires_Executive_Approval__c`, `Order_Count__c` and `Last_Engagement_Date__c`.

## What is in here

| Rule | Fail | Pass |
|---|---|---|
| SI-1 Attribution header | `QCDemoRenewalScoreService` | `QCDemoRenewalScoreServiceAttributed` |
| SI-2 Framework compliance | `QCDemoQuoteTrigger` | `QCDemoContractTrigger` |
| SI-3 Engagement scope guard | `QCDemoOpportunityCloseHandler` | `QCDemoOpportunityCloseHandlerInScope` |
| SI-4 AI code declaration | `QCDemoLeadScoreCalculator` | `QCDemoLeadScoreCalculatorDeclared` |
| SI-5 Async pattern | `QCDemoVendorNotifier` | `QCDemoVendorNotifierQueueable` |

Supporting the SI-2 pass artefact: `QCDemoTriggerHandler` (the framework base class), `QCDemoContractTriggerHandler` and `QCDemoContractService`. Open the chain on screen if the audience is technical.

## A note on the pairs

Every fail and pass pair is functionally equivalent on purpose. Both do the same job and return the same result for the client. The only difference is whether they follow your standard. That is what makes the demo persuasive: it is not clean code versus broken code, it is compliant versus non compliant, and only one of those is detectable without a governance layer you own.
