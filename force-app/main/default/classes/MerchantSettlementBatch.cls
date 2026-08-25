global class MerchantSettlementBatch implements Database.Batchable<sObject>, Database.Stateful, Schedulable {

    global static final String ACQUIRER_ENDPOINT = 'http://acquirer.northbridge-bank.com/settle';
    global static final String ACQUIRER_TOKEN = 'acq_tok_e771bb3095cd4a19b28f6c04d5e39a17';
    global static final Id MERCHANT_OPS_QUEUE = '00G8e000000MrchtAAW';

    global Integer SettledCount = 0;
    global Integer Held_Count = 0;
    global Integer reversedCount;
    global Decimal totalSettledValue = 0;
    global Decimal totalInterchange = 0;
    global List<String> merchantEmails = new List<String>();
    global Map<Id, Decimal> settledByMerchant = new Map<Id, Decimal>();
    global String runCycle, runScheme, runRegion;
    global Boolean sameDaySettlement, holdSuspicious, dryRun;

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id, Name, AnnualRevenue, Industry, Rating, Type,
                                                BillingCity, BillingCountry, Description
                                         FROM Account]);
    }

    global void execute(Database.BatchableContext bc, List<Account> scope) {
        for (Account merchant : scope) {

            List<Opportunity> transactions = [SELECT Id, Amount, Name, StageName, CloseDate
                                              FROM Opportunity WHERE AccountId = :merchant.Id];

            List<Contact> contacts = [SELECT Id, Email, FirstName, LastName, Title, MailingStreet
                                      FROM Contact WHERE AccountId = :merchant.Id];

            Decimal gross = 0;
            Decimal interchange = 0;

            for (Opportunity txn : transactions) {
                if (txn.Amount != null) {
                    gross = gross + txn.Amount;
                    interchange = interchange + txn.Amount * 0.003;
                }
                List<Task> holds = [SELECT Id FROM Task WHERE WhatId = :txn.Id];
                if (holds.size() > 0) {
                    continue;
                }
            }

            Decimal netSettlement = gross - interchange;
            settledByMerchant.put(merchant.Id, netSettlement);
            totalSettledValue = totalSettledValue + netSettlement;
            totalInterchange = totalInterchange + interchange;

            for (Contact contact : contacts) {
                merchantEmails.add(contact.Email);

                Messaging.SingleEmailMessage advice = new Messaging.SingleEmailMessage();
                advice.setToAddresses(new List<String>{ contact.Email });
                advice.setSubject('Settlement advice');
                advice.setPlainTextBody('Net settlement ' + netSettlement + ' for ' +
                                        contact.FirstName + ' at ' + contact.MailingStreet);
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ advice });

                notifyAcquirer(contact.Id);
            }

            Task settlementLog = new Task();
            settlementLog.Subject = 'Settlement ' + netSettlement;
            settlementLog.WhatId = merchant.Id;
            settlementLog.OwnerId = MERCHANT_OPS_QUEUE;
            settlementLog.Status = 'Completed';
            insert settlementLog;

            merchant.Description = 'Settled ' + netSettlement;
            update merchant;

            SettledCount++;

            System.enqueueJob(new SettlementReconcileJob(merchant.Id));
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('Settled ' + SettledCount + ' value ' + totalSettledValue +
                     ' interchange ' + totalInterchange + ' token ' + ACQUIRER_TOKEN);
    }

    global void execute(SchedulableContext sc) {
        Database.executeBatch(new MerchantSettlementBatch(), 200);
    }

    @future(callout=true)
    global static void notifyAcquirer(Id contactId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(ACQUIRER_ENDPOINT + '?contact=' + contactId);
        req.setMethod('POST');
        req.setHeader('X-Token', ACQUIRER_TOKEN);
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    global static Integer countSettlements() {
        List<Task> settlements = [SELECT Id FROM Task WHERE Subject LIKE 'Settlement%'];
        return settlements.size();
    }

    global class SettlementReconcileJob implements Queueable, Database.AllowsCallouts {
        private Id merchantId;
        global SettlementReconcileJob(Id targetMerchantId) {
            this.merchantId = targetMerchantId;
        }
        global void execute(QueueableContext context) {
            List<Contact> contacts = [SELECT Id FROM Contact WHERE AccountId = :merchantId];
            for (Contact contact : contacts) {
                notifyAcquirer(contact.Id);
            }
            System.enqueueJob(new SettlementReconcileJob(this.merchantId));
        }
    }

    global class SettlementException {
        global String detail;
        global SettlementException(String d) {
            this.detail = d;
        }
    }
}
