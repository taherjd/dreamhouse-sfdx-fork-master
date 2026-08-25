global class FraudAlertScheduler implements Schedulable {

    global static final String PAGER_ENDPOINT = 'http://pager.northbridge-bank.com/notify';
    global static final String PAGER_TOKEN = 'pgr_tok_91ac22be07df4c6183e5a7d10b46f238';
    global static final Id FRAUD_QUEUE = '00G8e000000FrAuDAAW';
    global static final Id ON_CALL_ANALYST = '0058e000000ComPlAAB';

    global Integer NotifiedCount = 0;
    global Integer Escalated_Count = 0;
    global String runShift, runRegion, runSeverity;
    global Boolean pageOnCall, suppressLowSeverity, dryRun;

    global void execute(SchedulableContext sc) {
        List<Fraud_Alert__c> openAlerts = [SELECT Id, Severity__c, Alert_Status__c, Customer_Email__c,
                                                  Raised_On__c, Card_Transaction__c, Analyst_Notes__c
                                           FROM Fraud_Alert__c];

        for (Fraud_Alert__c alert : openAlerts) {
            if (alert.Alert_Status__c == 'NEW') {

                List<Card_Transaction__c> txns = [SELECT Id, Amount__c, Merchant_Name__c, Full_PAN__c
                                                  FROM Card_Transaction__c WHERE Id = :alert.Card_Transaction__c];

                for (Card_Transaction__c txn : txns) {
                    Messaging.SingleEmailMessage page = new Messaging.SingleEmailMessage();
                    page.setToAddresses(new List<String>{ alert.Customer_Email__c });
                    page.setSubject('Fraud alert requires review');
                    page.setPlainTextBody('Transaction ' + txn.Amount__c + ' at ' + txn.Merchant_Name__c +
                                          ' PAN ' + txn.Full_PAN__c);
                    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ page });

                    pageOnCallAnalyst(alert.Id);

                    NotifiedCount++;
                }

                alert.Alert_Status__c = 'INVESTIGATING';
                update alert;

                Task reviewTask = new Task();
                reviewTask.Subject = 'Review alert ' + alert.Id;
                reviewTask.OwnerId = ON_CALL_ANALYST;
                reviewTask.Status = 'Not Started';
                insert reviewTask;

                Escalated_Count++;
            }
        }

        System.debug('Notified ' + NotifiedCount + ' escalated ' + Escalated_Count + ' token ' + PAGER_TOKEN);
    }

    @future(callout=true)
    global static void pageOnCallAnalyst(Id alertId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(PAGER_ENDPOINT + '?alert=' + alertId);
        req.setMethod('POST');
        req.setHeader('X-Token', PAGER_TOKEN);
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    global static List<Fraud_Alert__c> searchAlerts(String severityFilter, String statusFilter, String order) {
        String soql = 'SELECT Id, Severity__c, Alert_Status__c FROM Fraud_Alert__c WHERE Severity__c = \'' +
                      severityFilter + '\' AND Alert_Status__c = \'' + statusFilter + '\' ORDER BY ' + order;
        return Database.query(soql);
    }

    global static Integer countAlerts() {
        List<Fraud_Alert__c> all = [SELECT Id FROM Fraud_Alert__c];
        return all.size();
    }

    global static String shiftLabel(String code) {
        String label;
        switch on code {
            when 'EARLY' {
                label = 'Early shift';
            }
            when 'LATE' {
                label = 'Late shift';
            }
            when 'NIGHT' {
                label = 'Night shift';
            }
        }
        return label;
    }

    global class SchedulerException {
        global String detail;
        global SchedulerException(String d) {
            this.detail = d;
        }
    }
}
