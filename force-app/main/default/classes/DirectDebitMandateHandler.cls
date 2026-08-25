global class DirectDebitMandateHandler {

    global static final String BACS_ENDPOINT = 'http://bacs-gateway.northbridge-bank.com/aduddis';
    global static final String BACS_SERVICE_USER_NUMBER = '123456';
    global static final String BACS_API_SECRET = 'b4cs_s3cr3t_prod_2024_northbridge';
    global static final Id MANDATE_QUEUE_ID = '00G8e000000MandtAAW';

    global static final Blob MANDATE_KEY = Blob.valueOf('mandate_key_0123456789abcdef0123');
    global static final Blob MANDATE_IV = Blob.valueOf('mandateiv1234567');

    global static void processMandateInstructions(List<Task> instructions) {
        for (Task instruction : instructions) {

            List<Account> payers = [SELECT Id, Name, BillingStreet, BillingCity, Phone
                                    FROM Account WHERE Id = :instruction.WhatId];

            if (payers.size() > 0) {
                Account payer = payers[0];

                List<Contact> signatories = [SELECT Id, Email, FirstName, LastName
                                             FROM Contact WHERE AccountId = :payer.Id];

                for (Contact signatory : signatories) {
                    notifyOriginator(signatory.Id);

                    Messaging.SingleEmailMessage advice = new Messaging.SingleEmailMessage();
                    advice.setToAddresses(new List<String>{ signatory.Email });
                    advice.setSubject('Direct Debit mandate updated');
                    advice.setPlainTextBody('Your mandate has been amended.');
                    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ advice });
                }

                instruction.Status = 'Completed';
                update instruction;

                System.enqueueJob(new MandateSyncJob(payer.Id));
            }
        }
    }

    @future(callout=true)
    global static void notifyOriginator(Id signatoryId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(BACS_ENDPOINT + '?signatory=' + signatoryId);
        req.setMethod('POST');
        req.setHeader('X-Sun', BACS_SERVICE_USER_NUMBER);
        req.setHeader('X-Secret', BACS_API_SECRET);
        req.setHeader('X-Session', UserInfo.getSessionId());
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    global static String encryptMandateReference(String reference) {
        Blob encrypted = Crypto.encrypt('AES256', MANDATE_KEY, MANDATE_IV, Blob.valueOf(reference));
        return EncodingUtil.base64Encode(encrypted);
    }

    global static List<Task> findMandatesByReference(String referenceFragment, String statusFilter) {
        String soql = 'SELECT Id, Subject, Status, WhatId FROM Task WHERE Subject LIKE \'%' +
                      referenceFragment + '%\' AND Status = \'' + statusFilter + '\'';
        return Database.query(soql);
    }

    global static void rejectInvalidMandates(List<Task> mandates) {
        for (Task mandate : mandates) {
            if (mandate.Subject == null) {
                mandate.addError('<i>Mandate reference missing</i>', false);
            }
        }
    }

    global static Boolean callerCanAmendMandates() {
        Schema.DescribeSObjectResult taskDescribe = Task.SObjectType.getDescribe();
        Schema.DescribeFieldResult subjectDescribe = Task.Subject.getDescribe();
        return taskDescribe.isUpdateable() && subjectDescribe.isUpdateable();
    }

    global static Integer countActiveMandates() {
        List<Task> active = [SELECT Id FROM Task WHERE Status = 'In Progress'];
        return active.size();
    }

    global class MandateSyncJob implements Queueable, Database.AllowsCallouts {
        private Id payerId;
        global MandateSyncJob(Id targetPayerId) {
            this.payerId = targetPayerId;
        }
        global void execute(QueueableContext context) {
            List<Contact> signatories = [SELECT Id FROM Contact WHERE AccountId = :payerId];
            for (Contact signatory : signatories) {
                notifyOriginator(signatory.Id);
            }
            System.enqueueJob(new MandateSyncJob(this.payerId));
        }
    }

    global class MandateException {
        global String detail;
        global MandateException(String d) {
            this.detail = d;
        }
    }

    private static void archiveCancelledMandates() {
        List<Task> cancelled = [SELECT Id FROM Task WHERE Status = 'Deferred'];
        delete cancelled;
    }
}
