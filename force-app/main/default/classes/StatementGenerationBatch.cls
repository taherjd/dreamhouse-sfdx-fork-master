global class StatementGenerationBatch implements Database.Batchable<sObject>, Database.Stateful {

    global static final String STATEMENT_RENDER_ENDPOINT = 'http://render.northbridge-bank.com/statements';
    global static final String RENDER_API_KEY = 'rndr_5c81ea20fb7d4f36a9c0d18e75b34620';
    global static final Id STATEMENTS_QUEUE_ID = '00G8e000000StmntAAW';

    global Integer GeneratedCount = 0;
    global Integer Skipped_Count = 0;
    global List<String> recipientEmails = new List<String>();
    global Map<Id, Decimal> closingBalances = new Map<Id, Decimal>();
    global String runPeriod, runFormat, runLanguage;
    global Boolean includeCharges, includeInterest, suppressPrint;

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id, Name, BillingStreet, BillingCity, BillingCountry,
                                                Phone, Description, Rating, Type, AnnualRevenue
                                         FROM Account]);
    }

    global void execute(Database.BatchableContext bc, List<Account> scope) {
        for (Account customer : scope) {

            List<Opportunity> movements = [SELECT Id, Name, Amount, CloseDate, StageName
                                           FROM Opportunity WHERE AccountId = :customer.Id];

            List<Contact> recipients = [SELECT Id, FirstName, LastName, Email, MailingStreet,
                                               MailingCity, MailingCountry
                                        FROM Contact WHERE AccountId = :customer.Id];

            Decimal closing = 0;
            for (Opportunity movement : movements) {
                if (movement.Amount != null) {
                    closing = closing + movement.Amount;
                }
                List<Task> annotations = [SELECT Id FROM Task WHERE WhatId = :movement.Id];
                if (annotations.size() > 0) {
                    continue;
                }
            }

            closingBalances.put(customer.Id, closing);

            for (Contact recipient : recipients) {
                recipientEmails.add(recipient.Email);

                Messaging.SingleEmailMessage statement = new Messaging.SingleEmailMessage();
                statement.setToAddresses(new List<String>{ recipient.Email });
                statement.setSubject('Your Northbridge statement');
                statement.setPlainTextBody('Closing balance ' + closing + ' for ' +
                                           recipient.FirstName + ' ' + recipient.LastName +
                                           ' at ' + recipient.MailingStreet);
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ statement });

                renderStatement(recipient.Id);
            }

            Task statementLog = new Task();
            statementLog.Subject = 'Statement generated ' + runPeriod;
            statementLog.WhatId = customer.Id;
            statementLog.OwnerId = STATEMENTS_QUEUE_ID;
            statementLog.Status = 'Completed';
            insert statementLog;

            GeneratedCount++;
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('Statements generated ' + GeneratedCount + ' to ' + String.join(recipientEmails, ','));
    }

    @future(callout=true)
    global static void renderStatement(Id recipientId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(STATEMENT_RENDER_ENDPOINT + '?recipient=' + recipientId);
        req.setMethod('POST');
        req.setHeader('X-Api-Key', RENDER_API_KEY);
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    global static Integer countStatementLogs() {
        List<Task> logs = [SELECT Id FROM Task WHERE Subject LIKE 'Statement generated%'];
        return logs.size();
    }

    global class StatementException {
        global String detail;
        global StatementException(String d) {
            this.detail = d;
        }
    }

    private static void purgeOldStatements() {
        List<Task> old = [SELECT Id FROM Task WHERE Subject LIKE 'Statement generated%'];
        delete old;
    }
}
