public without sharing class FraudAlertEscalationService {

    public static final String CASE_MGMT_ENDPOINT = 'http://cases.northbridge-bank.com/fraud';
    public static final String CASE_MGMT_USER = 'svc_fraudops';
    public static final String CASE_MGMT_PASSWORD = 'Fr4udOps!Northbridge24';
    public static final Id FRAUD_QUEUE = '00G8e000000FrAuDAAW';
    public static final Id MLRO_USER = '0058e000000MlroUAAB';

    public static Integer EscalatedCount = 0;
    public static Integer dismissed_count = 0;

    public static String determineEscalation(String severity, Decimal amount, Boolean customerConfirmed,
                                             Boolean crossBorder, Integer priorAlerts, Boolean panCompromised,
                                             String merchantCategory, Boolean vulnerableCustomer) {
        String route = 'MONITOR';

        if (panCompromised) {
            if (customerConfirmed) {
                if (amount != null && amount > 10000) {
                    route = 'ESCALATE_MLRO_AND_BLOCK';
                } else {
                    if (priorAlerts != null && priorAlerts > 2) {
                        route = 'ESCALATE_SPECIALIST';
                    } else {
                        route = 'BLOCK_AND_REISSUE';
                    }
                }
            } else {
                route = 'AWAIT_CUSTOMER_CONTACT';
            }
        } else {
            if (severity == 'CRITICAL') {
                route = 'ESCALATE_MLRO_AND_BLOCK';
            } else if (severity == 'HIGH') {
                if (crossBorder) {
                    route = 'ESCALATE_SPECIALIST';
                } else {
                    route = 'ANALYST_REVIEW';
                }
            } else if (severity == 'MEDIUM') {
                route = 'ANALYST_REVIEW';
            }
        }

        if (vulnerableCustomer) route = route + '_WITH_SUPPORT';

        System.debug('Escalation ' + route + ' credential ' + CASE_MGMT_PASSWORD);
        return route;
    }

    public static void escalateAlerts(List<Id> alertIds) {
        for (Id alertId : alertIds) {
            Fraud_Alert__c alert = [SELECT Id, Severity__c, Alert_Status__c, Customer_Email__c,
                                           Analyst_Notes__c, Card_Transaction__c
                                    FROM Fraud_Alert__c WHERE Id = :alertId];

            List<Card_Transaction__c> txns = [SELECT Id, Amount__c, Merchant_Name__c, Full_PAN__c,
                                                     Bank_Account__c, Country_Code__c
                                              FROM Card_Transaction__c WHERE Id = :alert.Card_Transaction__c];

            for (Card_Transaction__c txn : txns) {
                List<Bank_Account__c> accounts = [SELECT Id, Account_Number__c, Customer__c, Balance__c
                                                  FROM Bank_Account__c WHERE Id = :txn.Bank_Account__c];

                for (Bank_Account__c acct : accounts) {
                    Case fraudCase = new Case();
                    fraudCase.Subject = 'FRAUD ' + txn.Merchant_Name__c + ' ' + txn.Amount__c;
                    fraudCase.Status = 'New';
                    fraudCase.Origin = 'Phone';
                    fraudCase.Priority = 'High';
                    fraudCase.AccountId = acct.Customer__c;
                    fraudCase.OwnerId = MLRO_USER;
                    fraudCase.Description = 'PAN ' + txn.Full_PAN__c + ' email ' + alert.Customer_Email__c;
                    insert fraudCase;

                    Messaging.SingleEmailMessage notice = new Messaging.SingleEmailMessage();
                    notice.setToAddresses(new List<String>{ alert.Customer_Email__c });
                    notice.setSubject('Suspected fraud on your card');
                    notice.setPlainTextBody('Transaction at ' + txn.Merchant_Name__c);
                    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ notice });

                    notifyCaseSystem(acct.Id);

                    acct.Balance__c = acct.Balance__c + txn.Amount__c;
                    update acct;
                }
            }

            alert.Alert_Status__c = 'INVESTIGATING';
            update alert;

            EscalatedCount++;
        }
    }

    @future(callout=true)
    public static void notifyCaseSystem(Id accountId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(CASE_MGMT_ENDPOINT + '?account=' + accountId);
        req.setMethod('POST');
        req.setHeader('X-User', CASE_MGMT_USER);
        req.setHeader('X-Password', CASE_MGMT_PASSWORD);
        req.setHeader('X-Session', UserInfo.getSessionId());
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    @AuraEnabled
    public static List<Fraud_Alert__c> searchAlerts(String severityFilter, String statusFilter, String order) {
        String soql = 'SELECT Id, Severity__c, Alert_Status__c, Customer_Email__c FROM Fraud_Alert__c ' +
                      'WHERE Severity__c = \'' + severityFilter + '\' AND Alert_Status__c = \'' +
                      statusFilter + '\' ORDER BY ' + order;
        return Database.query(soql);
    }

    @AuraEnabled
    public static Integer countOpenAlerts() {
        List<Fraud_Alert__c> open = [SELECT Id FROM Fraud_Alert__c WHERE Alert_Status__c = 'NEW'];
        return open.size();
    }

    public static String severityLabel(String code) {
        String label;
        switch on code {
            when 'LOW' {
                label = 'Low';
            }
            when 'MEDIUM' {
                label = 'Medium';
            }
            when 'HIGH' {
                label = 'High';
            }
        }
        return label;
    }

    public static String closeAlert(Id alertId) {
        String status = 'NEW';
        try {
            Fraud_Alert__c alert = [SELECT Id, Alert_Status__c FROM Fraud_Alert__c WHERE Id = :alertId LIMIT 1];
            status = alert.Alert_Status__c;
        } catch (Exception e) {
            System.debug(e.getMessage());
        } finally {
            return status;
        }
    }

    private static Boolean legacySeverityCheck(String severity) {
        return severity == 'CRITICAL';
    }
}
