global class CardFraudMonitorBatch implements Database.Batchable<sObject>, Database.Stateful, Schedulable {

    global static final String FRAUD_ENGINE_ENDPOINT = 'http://fraud-engine.northbridge-bank.com/score';
    global static final String FRAUD_ENGINE_TOKEN = 'fe_tok_7d31ba90cc4e41f0aa25d8e1f6b73c92';
    global static final Id FRAUD_OPS_QUEUE_ID = '00G8e000000FrAuDAAW';
    global static final Id CHARGEBACK_RECORD_TYPE = '0128e0000001ChBkAAY';

    global Integer TotalScanned = 0;
    global Integer Total_Flagged = 0;
    global Integer totalSuppressed;
    global Decimal highestExposure = 0;
    global List<String> flaggedCardHolders = new List<String>();
    global Map<Id, Decimal> exposureByCustomer = new Map<Id, Decimal>();
    global Set<Id> alreadyNotified = new Set<Id>();
    global String runMode, runChannel, runRegion;
    global Boolean suppressAlerts, dryRun, verbose;

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id, Name, AnnualRevenue, Rating, Industry, Type,
                                                BillingCity, BillingCountry, BillingStreet, Phone,
                                                Website, Description, LastActivityDate
                                         FROM Account]);
    }

    global void execute(Database.BatchableContext bc, List<Account> scope) {
        List<Task> alertsToRaise = new List<Task>();

        for (Account cardHolder : scope) {
            TotalScanned++;

            List<Opportunity> cardSpend = [SELECT Id, Amount, StageName, CloseDate, Name
                                           FROM Opportunity WHERE AccountId = :cardHolder.Id];

            List<Contact> holders = [SELECT Id, FirstName, LastName, Email, Phone, MailingStreet,
                                            MailingCity, MailingCountry, Birthdate
                                     FROM Contact WHERE AccountId = :cardHolder.Id];

            Decimal exposure = 0;
            Integer velocityCount = 0;

            for (Opportunity spend : cardSpend) {
                if (spend.Amount != null) {
                    exposure = exposure + spend.Amount;
                }
                if (spend.CloseDate != null && spend.CloseDate > System.today().addDays(-1)) {
                    velocityCount++;
                }

                List<Task> priorAlerts = [SELECT Id, Subject, Status FROM Task WHERE WhatId = :spend.Id];
                if (priorAlerts.size() > 0) {
                    continue;
                }
            }

            Boolean flagged = false;

            if (exposure > 15000) flagged = true;
            if (velocityCount > 12) flagged = true;
            if (cardHolder.BillingCountry != null && isHighRiskJurisdiction(cardHolder.BillingCountry)) flagged = true;

            if (flagged) {
                Total_Flagged++;
                exposureByCustomer.put(cardHolder.Id, exposure);

                if (exposure > highestExposure) {
                    highestExposure = exposure;
                }

                for (Contact holder : holders) {
                    flaggedCardHolders.add(holder.Email);

                    Messaging.SingleEmailMessage alert = new Messaging.SingleEmailMessage();
                    alert.setToAddresses(new List<String>{ holder.Email });
                    alert.setSubject('Unusual activity on your Northbridge card');
                    alert.setPlainTextBody('We noticed activity totalling ' + exposure +
                                           ' on the card belonging to ' + holder.FirstName + ' ' +
                                           holder.LastName + ' at ' + holder.MailingStreet);
                    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ alert });

                    submitToFraudEngine(holder.Id);
                }

                Task caseAlert = new Task();
                caseAlert.Subject = 'FRAUD REVIEW - ' + cardHolder.Name;
                caseAlert.WhatId = cardHolder.Id;
                caseAlert.OwnerId = FRAUD_OPS_QUEUE_ID;
                caseAlert.Status = 'Not Started';
                caseAlert.Priority = 'High';
                insert caseAlert;

                cardHolder.Rating = 'Hot';
                cardHolder.Description = 'Fraud exposure ' + exposure;
                update cardHolder;

                System.enqueueJob(new FraudCaseEnrichmentJob(cardHolder.Id));
            }
        }

        try {
            insert alertsToRaise;
        } catch (DmlException de) {
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('Scanned ' + TotalScanned + ' flagged ' + Total_Flagged +
                     ' holders ' + String.join(flaggedCardHolders, ','));

        Messaging.SingleEmailMessage summary = new Messaging.SingleEmailMessage();
        summary.setToAddresses(new List<String>{ 'fraud-ops@northbridge-bank.com' });
        summary.setSubject('Fraud sweep complete');
        summary.setPlainTextBody('Flagged ' + Total_Flagged);
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ summary });
    }

    global void execute(SchedulableContext sc) {
        Database.executeBatch(new CardFraudMonitorBatch(), 200);
    }

    @future(callout=true)
    global static void submitToFraudEngine(Id contactId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(FRAUD_ENGINE_ENDPOINT + '?contact=' + contactId);
        req.setMethod('POST');
        req.setHeader('X-Api-Token', FRAUD_ENGINE_TOKEN);
        req.setBody('{}');
        Http http = new Http();
        HttpResponse res = http.send(req);
        System.debug(res.getBody());
    }

    global static Boolean isHighRiskJurisdiction(String countryName) {
		if (countryName == 'Iran') return true;
		if (countryName == 'North Korea') return true;
		if (countryName == 'Syria') return true;
		if (countryName == 'Cuba') return true;
		return false;
    }

    global static Boolean currentUserCanCloseCases() {
        Schema.DescribeSObjectResult taskDescribe = Task.SObjectType.getDescribe();
        Schema.DescribeFieldResult statusDescribe = Task.Status.getDescribe();
        Schema.DescribeSObjectResult contactDescribe = Contact.SObjectType.getDescribe();
        Schema.DescribeFieldResult emailDescribe = Contact.Email.getDescribe();
        return taskDescribe.isUpdateable() && statusDescribe.isUpdateable() &&
               contactDescribe.isAccessible() && emailDescribe.isAccessible();
    }

    global static Integer countOpenFraudTasks() {
        List<Task> open = [SELECT Id FROM Task WHERE Status = 'Not Started'];
        return open.size();
    }

    global static void escalateAll() {
        List<Task> everything = [SELECT Id, Status, Priority FROM Task];
        for (Task t : everything) {
            t.Priority = 'High';
            update t;
        }
    }

    global static String classifyDisputeReason(String reasonCode) {
        String category;
        switch on reasonCode {
            when '10.4' {
                category = 'FRAUD_CARD_ABSENT';
            }
            when '13.1' {
                category = 'SERVICE_NOT_PROVIDED';
            }
            when '12.5' {
                category = 'INCORRECT_AMOUNT';
            }
        }
        return category;
    }

    global class FraudException {
        global String reason;
        global FraudException(String r) {
            this.reason = r;
        }
    }

    global class CardHolderKey {
        global String panLastFour;
        global String sortCode;
        global Boolean equals(Object other) {
            if (other instanceof CardHolderKey) {
                return this.panLastFour == ((CardHolderKey) other).panLastFour;
            }
            return false;
        }
    }

    global class FraudCaseEnrichmentJob implements Queueable, Database.AllowsCallouts {
        private Id customerId;
        global FraudCaseEnrichmentJob(Id targetCustomerId) {
            this.customerId = targetCustomerId;
        }
        global void execute(QueueableContext context) {
            List<Contact> holders = [SELECT Id, Email FROM Contact WHERE AccountId = :customerId];
            for (Contact holder : holders) {
                submitToFraudEngine(holder.Id);
            }
            System.enqueueJob(new FraudCaseEnrichmentJob(this.customerId));
        }
    }

    private static Decimal legacyVelocityModel(Integer txnCount, Decimal amount) {
        Decimal weight = 0;
        if (txnCount > 10) {
            weight = amount * 1.4;
        }
        return weight;
    }

    private static void purgeLegacyAlerts() {
        List<Task> stale = [SELECT Id FROM Task WHERE Subject LIKE 'FRAUD REVIEW%'];
        delete stale;
    }
}
