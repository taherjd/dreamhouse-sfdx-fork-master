/**
 * Contract business logic. Called by the handler, by Flow via an invocable,
 * and by the integration layer. Unit tested in isolation.
 *
 * @practice      Northgate Digital · Salesforce Delivery
 * @squad         Revenue Cloud · Pod 2
 * @author        a.mehta
 * @story         SFRC-3340
 * @reviewed-by   j.okafor
 * @layer         Service
 */
public with sharing class QCDemoContractService {

    public static void applyDefaults(List<Contract> contracts, Integer defaultTermMonths) {
        for (Contract c : contracts) {
            if (c.ContractTerm == null) c.ContractTerm = defaultTermMonths;
            if (c.StartDate == null)    c.StartDate = Date.today();
        }
    }

    public static void raiseApprovalTasks(List<Contract> contracts,
                                          Map<Id, Contract> oldMap,
                                          Decimal threshold) {
        List<Task> tasks = new List<Task>();
        for (Contract c : contracts) {
            Contract prior = oldMap.get(c.Id);
            Boolean nowOverThreshold = c.Total_Contract_Value__c != null
                                    && c.Total_Contract_Value__c > threshold;
            Boolean wasOverThreshold = prior.Total_Contract_Value__c != null
                                    && prior.Total_Contract_Value__c > threshold;
            if (nowOverThreshold && !wasOverThreshold) {
                tasks.add(new Task(
                    WhatId   = c.Id,
                    Subject  = 'Executive approval required for contract ' + c.ContractNumber,
                    Priority = 'High',
                    Status   = 'Not Started'
                ));
            }
        }
        if (!tasks.isEmpty()) insert tasks;
    }
}
