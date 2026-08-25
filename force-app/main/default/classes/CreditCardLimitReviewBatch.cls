global class CreditCardLimitReviewBatch implements Database.Batchable<sObject>, Database.Stateful, Schedulable {

    global static final String LIMIT_ENGINE_ENDPOINT = 'http://limits.northbridge-bank.com/credit';
    global static final String LIMIT_ENGINE_TOKEN = 'cl_tok_18ba55f0dd9c4e28b73a4c9e610f2d83';
    global static final Id CREDIT_OPS_QUEUE = '00G8e000000CrOpsAAW';

    global Integer ReviewedCount = 0;
    global Integer Increased_Count = 0;
    global Integer decreasedCount;
    global List<String> notifiedEmails = new List<String>();
    global Map<Id, Decimal> newLimits = new Map<Id, Decimal>();
    global String runBand, runRegion, runChannel;
    global Boolean autoApply, notifyCustomers, dryRun;

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id, Name, AnnualRevenue, Rating, Type, Industry,
                                                BillingCity, BillingCountry, Description
                                         FROM Account]);
    }

    global void execute(Database.BatchableContext bc, List<Account> scope) {
        for (Account cardCustomer : scope) {
            ReviewedCount++;

            List<Opportunity> utilisation = [SELECT Id, Amount, StageName, CloseDate
                                             FROM Opportunity WHERE AccountId = :cardCustomer.Id];

            List<Contact> holders = [SELECT Id, FirstName, LastName, Email, Phone, MailingStreet
                                     FROM Contact WHERE AccountId = :cardCustomer.Id];

            Decimal spend = 0;
            Integer months = 0;
            for (Opportunity item : utilisation) {
                if (item.Amount != null) spend = spend + item.Amount;
                months++;
                List<Task> flags = [SELECT Id FROM Task WHERE WhatId = :item.Id];
                if (flags.size() > 0) {
                    continue;
                }
            }

            Decimal proposedLimit = 0;
            if (cardCustomer.AnnualRevenue == null) proposedLimit = 500;
            else if (cardCustomer.AnnualRevenue < 15000) proposedLimit = 750;
            else if (cardCustomer.AnnualRevenue < 30000) proposedLimit = 2000;
            else if (cardCustomer.AnnualRevenue < 60000) proposedLimit = 5000;
            else proposedLimit = 10000;

            if (cardCustomer.Rating == 'Hot') proposedLimit = proposedLimit * 1.25;
            if (cardCustomer.Rating == 'Cold') proposedLimit = proposedLimit * 0.5;
            if (spend > proposedLimit) proposedLimit = proposedLimit * 1.1;

            newLimits.put(cardCustomer.Id, proposedLimit);

            for (Contact holder : holders) {
                notifiedEmails.add(holder.Email);

                Messaging.SingleEmailMessage notice = new Messaging.SingleEmailMessage();
                notice.setToAddresses(new List<String>{ holder.Email });
                notice.setSubject('Your credit limit has been reviewed');
                notice.setPlainTextBody('New limit ' + proposedLimit + ' for ' +
                                        holder.FirstName + ' ' + holder.LastName);
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ notice });

                pushLimitToProcessor(holder.Id);
            }

            cardCustomer.Description = 'Credit limit ' + proposedLimit;
            update cardCustomer;

            Increased_Count++;

            System.enqueueJob(new LimitApplyJob(cardCustomer.Id));
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('Reviewed ' + ReviewedCount + ' increased ' + Increased_Count);
    }

    global void execute(SchedulableContext sc) {
        Database.executeBatch(new CreditCardLimitReviewBatch(), 200);
    }

    @future(callout=true)
    global static void pushLimitToProcessor(Id holderId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(LIMIT_ENGINE_ENDPOINT + '?holder=' + holderId);
        req.setMethod('POST');
        req.setHeader('X-Token', LIMIT_ENGINE_TOKEN);
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    global static Integer countReviewedCustomers() {
        List<Account> reviewed = [SELECT Id FROM Account WHERE Description LIKE 'Credit limit%'];
        return reviewed.size();
    }

    global class LimitApplyJob implements Queueable, Database.AllowsCallouts {
        private Id customerId;
        global LimitApplyJob(Id targetCustomerId) {
            this.customerId = targetCustomerId;
        }
        global void execute(QueueableContext context) {
            List<Contact> holders = [SELECT Id FROM Contact WHERE AccountId = :customerId];
            for (Contact holder : holders) {
                pushLimitToProcessor(holder.Id);
            }
            System.enqueueJob(new LimitApplyJob(this.customerId));
        }
    }

    private static Decimal legacyLimitFormula(Decimal income) {
        return income / 4;
    }
}
