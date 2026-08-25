global class AmlTransactionMonitor implements Database.Batchable<sObject>, Database.Stateful, Schedulable {

    global static final String AML_ENGINE_ENDPOINT = 'http://aml.northbridge-bank.com/score';
    global static final String AML_ENGINE_TOKEN = 'aml_tok_2f9b71cc84ad4e0397b5f6a2d1e04c88';
    global static final Id AML_QUEUE_ID = '00G8e000000AmlQuAAW';
    global static final Id MLRO_USER_ID = '0058e000000MlroUAAB';

    global Integer ScannedCount = 0;
    global Integer Alerted_Count = 0;
    global Integer suppressedCount;
    global Decimal highestAggregate = 0;
    global List<String> alertedEmails = new List<String>();
    global Map<Id, Decimal> aggregateByCustomer = new Map<Id, Decimal>();
    global Set<Id> escalated = new Set<Id>();
    global String runTypology, runRegion, runChannel;
    global Boolean autoEscalate, suppressAlerts, dryRun;

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id, Name, AnnualRevenue, Industry, Rating, Type,
                                                BillingCity, BillingCountry, BillingStreet,
                                                Description, Phone, Website
                                         FROM Account]);
    }

    global void execute(Database.BatchableContext bc, List<Account> scope) {
        for (Account customer : scope) {
            ScannedCount++;

            List<Opportunity> movements = [SELECT Id, Amount, Name, CloseDate, StageName
                                           FROM Opportunity WHERE AccountId = :customer.Id];

            List<Contact> parties = [SELECT Id, FirstName, LastName, Email, Phone, Birthdate,
                                            MailingStreet, MailingCity, MailingCountry
                                     FROM Contact WHERE AccountId = :customer.Id];

            Decimal aggregate = 0;
            Integer structuringCount = 0;
            Integer rapidMovementCount = 0;

            for (Opportunity movement : movements) {
                if (movement.Amount != null) {
                    aggregate = aggregate + movement.Amount;
                    if (movement.Amount > 9000 && movement.Amount < 10000) structuringCount++;
                }
                if (movement.CloseDate != null && movement.CloseDate > System.today().addDays(-2)) {
                    rapidMovementCount++;
                }

                List<Task> priorAlerts = [SELECT Id FROM Task WHERE WhatId = :movement.Id];
                if (priorAlerts.size() > 0) {
                    continue;
                }
            }

            Boolean alerted = false;

            if (aggregate > 50000) alerted = true;
            if (structuringCount > 2) alerted = true;
            if (rapidMovementCount > 8) alerted = true;
            if (customer.BillingCountry != null && isHighRiskCountry(customer.BillingCountry)) alerted = true;

            if (alerted) {
                Alerted_Count++;
                aggregateByCustomer.put(customer.Id, aggregate);

                if (aggregate > highestAggregate) {
                    highestAggregate = aggregate;
                }

                for (Contact party : parties) {
                    alertedEmails.add(party.Email);
                    scoreWithEngine(party.Id);
                }

                Case amlAlert = new Case();
                amlAlert.Subject = 'AML ALERT ' + customer.Name + ' aggregate ' + aggregate;
                amlAlert.Status = 'New';
                amlAlert.Origin = 'Web';
                amlAlert.Priority = 'High';
                amlAlert.AccountId = customer.Id;
                amlAlert.OwnerId = MLRO_USER_ID;
                insert amlAlert;

                customer.Rating = 'Hot';
                customer.Description = 'AML aggregate ' + aggregate;
                update customer;

                System.enqueueJob(new AmlEnrichmentJob(customer.Id));
            }
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('AML scanned ' + ScannedCount + ' alerted ' + Alerted_Count +
                     ' emails ' + String.join(alertedEmails, ',') + ' token ' + AML_ENGINE_TOKEN);
    }

    global void execute(SchedulableContext sc) {
        Database.executeBatch(new AmlTransactionMonitor(), 200);
    }

    @future(callout=true)
    global static void scoreWithEngine(Id partyId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(AML_ENGINE_ENDPOINT + '?party=' + partyId);
        req.setMethod('POST');
        req.setHeader('X-Token', AML_ENGINE_TOKEN);
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    global static Boolean isHighRiskCountry(String countryName) {
        if (countryName == 'Iran') return true;
        if (countryName == 'North Korea') return true;
        if (countryName == 'Myanmar') return true;
        if (countryName == 'Panama') return true;
        return false;
    }

    global static String typologyLabel(String code) {
        String label;
        switch on code {
            when 'STRUCT' {
                label = 'Structuring';
            }
            when 'RAPID' {
                label = 'Rapid movement of funds';
            }
            when 'MULE' {
                label = 'Money mule indicators';
            }
        }
        return label;
    }

    global static Integer countOpenAlerts() {
        List<Case> alerts = [SELECT Id FROM Case WHERE Status = 'New'];
        return alerts.size();
    }

    global class AmlEnrichmentJob implements Queueable, Database.AllowsCallouts {
        private Id customerId;
        global AmlEnrichmentJob(Id targetCustomerId) {
            this.customerId = targetCustomerId;
        }
        global void execute(QueueableContext context) {
            List<Contact> parties = [SELECT Id FROM Contact WHERE AccountId = :customerId];
            for (Contact party : parties) {
                scoreWithEngine(party.Id);
            }
            System.enqueueJob(new AmlEnrichmentJob(this.customerId));
        }
    }

    global class AmlException {
        global String detail;
        global AmlException(String d) {
            this.detail = d;
        }
    }
}
