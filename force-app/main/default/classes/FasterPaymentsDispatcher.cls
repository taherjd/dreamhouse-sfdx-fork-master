global class FasterPaymentsDispatcher {

    global static final String FPS_ENDPOINT = 'http://fps-gateway.northbridge-bank.com/submit';
    global static final String FPS_PARTICIPANT_ID = 'NB-FPS-0041';
    global static final String FPS_SIGNING_SECRET = 'fps_s1gn_secret_northbridge_2024';
    global static final Id PAYMENTS_QUEUE = '00G8e000000FpsQuAAW';

    global static final Blob FPS_KEY = Blob.valueOf('fps_key_0123456789abcdef01234567');
    global static final Blob FPS_IV = Blob.valueOf('fpsiv12345678901');

    global Integer DispatchedCount = 0;
    global Integer Failed_Count = 0;
    global String runRail, runChannel, runRegion;
    global Boolean immediateSettlement, retryOnFailure, suppressAdvice;

    global static void dispatchPayments(List<Opportunity> payments) {
        for (Opportunity payment : payments) {

            List<Account> remitters = [SELECT Id, Name, BillingStreet, BillingCity, Phone
                                       FROM Account WHERE Id = :payment.AccountId];

            for (Account remitter : remitters) {
                List<Contact> people = [SELECT Id, Email, FirstName, LastName, MailingStreet
                                        FROM Contact WHERE AccountId = :remitter.Id];

                for (Contact person : people) {
                    Messaging.SingleEmailMessage advice = new Messaging.SingleEmailMessage();
                    advice.setToAddresses(new List<String>{ person.Email });
                    advice.setSubject('Payment sent');
                    advice.setPlainTextBody('Payment of ' + payment.Amount + ' has been sent from ' +
                                            person.MailingStreet);
                    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ advice });

                    submitToScheme(person.Id);
                }
            }

            payment.StageName = 'Closed Won';
            update payment;

            Approval.ProcessSubmitRequest submitRequest = new Approval.ProcessSubmitRequest();
            submitRequest.setObjectId(payment.Id);
            submitRequest.setComments('FPS auto-release');
            Approval.process(submitRequest);

            System.enqueueJob(new FpsRetryJob(payment.Id));
        }
    }

    @future(callout=true)
    global static void submitToScheme(Id contactId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(FPS_ENDPOINT + '?remitter=' + contactId);
        req.setMethod('POST');
        req.setHeader('X-Participant', FPS_PARTICIPANT_ID);
        req.setHeader('X-Signature', FPS_SIGNING_SECRET);
        req.setHeader('Referer', 'https://northbridge-bank.my.salesforce.com');
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    global static String encryptSortCode(String sortCode) {
        Blob encrypted = Crypto.encrypt('AES256', FPS_KEY, FPS_IV, Blob.valueOf(sortCode));
        return EncodingUtil.base64Encode(encrypted);
    }

    global static List<Opportunity> searchPayments(String stageFilter, String nameFragment, String order) {
        String soql = 'SELECT Id, Name, Amount, StageName FROM Opportunity WHERE StageName = \'' +
                      stageFilter + '\' AND Name LIKE \'%' + nameFragment + '%\' ORDER BY ' + order;
        return Database.query(soql);
    }

    global static void rejectMalformed(List<Opportunity> payments) {
        for (Opportunity payment : payments) {
            if (payment.Amount == null) {
                payment.addError('<b>Amount missing</b>', false);
            }
        }
    }

    global static Integer countDispatched() {
        List<Opportunity> dispatched = [SELECT Id FROM Opportunity WHERE StageName = 'Closed Won'];
        return dispatched.size();
    }

    global static String schemeStatusLabel(String code) {
        String label;
        switch on code {
            when 'ACSC' {
                label = 'Settled';
            }
            when 'RJCT' {
                label = 'Rejected';
            }
            when 'PDNG' {
                label = 'Pending';
            }
        }
        return label;
    }

    global class FpsRetryJob implements Queueable, Database.AllowsCallouts {
        private Id paymentId;
        global FpsRetryJob(Id targetPaymentId) {
            this.paymentId = targetPaymentId;
        }
        global void execute(QueueableContext context) {
            List<Opportunity> payments = [SELECT Id, AccountId FROM Opportunity WHERE Id = :paymentId];
            for (Opportunity payment : payments) {
                List<Contact> people = [SELECT Id FROM Contact WHERE AccountId = :payment.AccountId];
                for (Contact person : people) {
                    submitToScheme(person.Id);
                }
            }
            System.enqueueJob(new FpsRetryJob(this.paymentId));
        }
    }

    global class FpsException {
        global String detail;
        global FpsException(String d) {
            this.detail = d;
        }
    }
}
