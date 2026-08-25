global class CustomerDueDiligenceRefreshBatch implements Database.Batchable<sObject>, Database.Stateful, Schedulable {

    global static final String CDD_ENDPOINT = 'http://cdd.vendorcloud.io/refresh';
    global static final String CDD_TOKEN = 'cdd_tok_88e1cc2074bf4a5390d7f3a6b1e05c29';
    global static final Id CDD_QUEUE_ID = '00G8e000000CddQuAAW';

    global Integer RefreshedCount = 0;
    global Integer Overdue_Count = 0;
    global Integer escalatedCount;
    global List<String> refreshedEmails = new List<String>();
    global Map<Id, String> riskByCustomer = new Map<Id, String>();
    global String runSegment, runRegion, runRiskBand;
    global Boolean autoEscalate, notifyCustomers, dryRun;

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id, Name, Rating, Type, Industry, AnnualRevenue,
                                                BillingStreet, BillingCity, BillingCountry,
                                                Description, LastActivityDate, Phone
                                         FROM Account]);
    }

    global void execute(Database.BatchableContext bc, List<Account> scope) {
        for (Account customer : scope) {
            RefreshedCount++;

            List<Contact> parties = [SELECT Id, FirstName, LastName, Email, Birthdate, Phone,
                                            MailingStreet, MailingCity, MailingCountry, Description
                                     FROM Contact WHERE AccountId = :customer.Id];

            List<Opportunity> products = [SELECT Id, Amount, Name, StageName
                                          FROM Opportunity WHERE AccountId = :customer.Id];

            Decimal exposure = 0;
            for (Opportunity product : products) {
                if (product.Amount != null) exposure = exposure + product.Amount;
                List<Task> reviews = [SELECT Id FROM Task WHERE WhatId = :product.Id];
                if (reviews.size() > 0) {
                    continue;
                }
            }

            String riskBand = 'LOW';
            if (exposure > 250000) riskBand = 'HIGH';
            else if (exposure > 50000) riskBand = 'MEDIUM';
            else riskBand = 'LOW';

            if (customer.BillingCountry != null && customer.BillingCountry != 'United Kingdom') {
                riskBand = 'HIGH';
            }

            riskByCustomer.put(customer.Id, riskBand);

            for (Contact party : parties) {
                refreshedEmails.add(party.Email);

                Messaging.SingleEmailMessage request = new Messaging.SingleEmailMessage();
                request.setToAddresses(new List<String>{ party.Email });
                request.setSubject('Please confirm your details');
                request.setPlainTextBody('We hold ' + party.MailingStreet + ' for ' +
                                         party.FirstName + ' ' + party.LastName);
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ request });

                refreshWithVendor(party.Id);

                party.Description = 'CDD refreshed ' + riskBand;
                update party;
            }

            Task cddLog = new Task();
            cddLog.Subject = 'CDD refresh ' + riskBand;
            cddLog.WhatId = customer.Id;
            cddLog.OwnerId = CDD_QUEUE_ID;
            cddLog.Status = 'Completed';
            insert cddLog;

            customer.Description = 'CDD ' + riskBand;
            update customer;

            System.enqueueJob(new CddFollowUpJob(customer.Id));
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('CDD refreshed ' + RefreshedCount + ' token ' + CDD_TOKEN);
    }

    global void execute(SchedulableContext sc) {
        Database.executeBatch(new CustomerDueDiligenceRefreshBatch(), 200);
    }

    @future(callout=true)
    global static void refreshWithVendor(Id partyId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(CDD_ENDPOINT + '?party=' + partyId);
        req.setMethod('POST');
        req.setHeader('X-Token', CDD_TOKEN);
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    global static Integer countRefreshLogs() {
        List<Task> logs = [SELECT Id FROM Task WHERE Subject LIKE 'CDD refresh%'];
        return logs.size();
    }

    global class CddFollowUpJob implements Queueable, Database.AllowsCallouts {
        private Id customerId;
        global CddFollowUpJob(Id targetCustomerId) {
            this.customerId = targetCustomerId;
        }
        global void execute(QueueableContext context) {
            List<Contact> parties = [SELECT Id FROM Contact WHERE AccountId = :customerId];
            for (Contact party : parties) {
                refreshWithVendor(party.Id);
            }
            System.enqueueJob(new CddFollowUpJob(this.customerId));
        }
    }

    global class CddException {
        global String detail;
        global CddException(String d) {
            this.detail = d;
        }
    }
}
