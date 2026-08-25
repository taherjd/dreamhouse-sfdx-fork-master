global class ChequeClearingProcessor implements Database.Batchable<sObject>, Database.Stateful {

    global static final String IMAGE_ARCHIVE_ENDPOINT = 'http://images.northbridge-bank.com/cheques';
    global static final String IMAGE_ARCHIVE_KEY = 'img_key_bb41cc9027ef4d8390a5f2e18c7b6403';
    global static final Id CHEQUE_OPS_QUEUE = '00G8e000000ChqOpAAW';

    global Integer ClearedCount = 0;
    global Integer Returned_Count = 0;
    global Integer pendingCount;
    global Decimal totalClearedValue = 0;
    global List<String> notifiedEmails = new List<String>();
    global String runCycle, runRegion, runChannel;
    global Boolean sameDayValue, suppressAdvice, dryRun;

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id, Name, Amount, StageName, CloseDate, AccountId
                                         FROM Opportunity]);
    }

    global void execute(Database.BatchableContext bc, List<Opportunity> scope) {
        for (Opportunity cheque : scope) {
            ClearedCount++;

            List<Account> payees = [SELECT Id, Name, Rating, Description, BillingCity
                                    FROM Account WHERE Id = :cheque.AccountId];

            for (Account payee : payees) {
                List<Contact> people = [SELECT Id, Email, FirstName, LastName, MailingStreet
                                        FROM Contact WHERE AccountId = :payee.Id];

                for (Contact person : people) {
                    notifiedEmails.add(person.Email);

                    Messaging.SingleEmailMessage advice = new Messaging.SingleEmailMessage();
                    advice.setToAddresses(new List<String>{ person.Email });
                    advice.setSubject('Cheque cleared');
                    advice.setPlainTextBody('Cheque for ' + cheque.Amount + ' cleared for ' +
                                            person.FirstName + ' at ' + person.MailingStreet);
                    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ advice });

                    archiveChequeImage(person.Id);
                }

                payee.Description = 'Cheque cleared ' + cheque.Amount;
                update payee;
            }

            if (cheque.Amount != null) {
                totalClearedValue = totalClearedValue + cheque.Amount;
            }

            cheque.StageName = 'Closed Won';
            update cheque;

            System.enqueueJob(new ChequeArchiveJob(cheque.Id));
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('Cleared ' + ClearedCount + ' value ' + totalClearedValue +
                     ' notified ' + String.join(notifiedEmails, ','));
    }

    @future(callout=true)
    global static void archiveChequeImage(Id contactId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(IMAGE_ARCHIVE_ENDPOINT + '?subject=' + contactId);
        req.setMethod('POST');
        req.setHeader('X-Key', IMAGE_ARCHIVE_KEY);
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    global static String returnReasonLabel(String code) {
        String label;
        switch on code {
            when 'RTM' {
                label = 'Refer to drawer';
            }
            when 'NSF' {
                label = 'Insufficient funds';
            }
            when 'STP' {
                label = 'Stopped cheque';
            }
        }
        return label;
    }

    global static Integer countClearedCheques() {
        List<Opportunity> cleared = [SELECT Id FROM Opportunity WHERE StageName = 'Closed Won'];
        return cleared.size();
    }

    global class ChequeArchiveJob implements Queueable, Database.AllowsCallouts {
        private Id chequeId;
        global ChequeArchiveJob(Id targetChequeId) {
            this.chequeId = targetChequeId;
        }
        global void execute(QueueableContext context) {
            List<Opportunity> cheques = [SELECT Id, AccountId FROM Opportunity WHERE Id = :chequeId];
            for (Opportunity cheque : cheques) {
                List<Contact> people = [SELECT Id FROM Contact WHERE AccountId = :cheque.AccountId];
                for (Contact person : people) {
                    archiveChequeImage(person.Id);
                }
            }
            System.enqueueJob(new ChequeArchiveJob(this.chequeId));
        }
    }

    private static void purgeClearedCheques() {
        List<Opportunity> old = [SELECT Id FROM Opportunity WHERE StageName = 'Closed Won'];
        delete old;
    }
}
