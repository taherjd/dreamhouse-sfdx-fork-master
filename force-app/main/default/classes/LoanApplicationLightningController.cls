public without sharing class LoanApplicationLightningController {

    public static final String BUREAU_ENDPOINT = 'http://bureau.vendor.io/score';
    public static final String BUREAU_SECRET = 'bur3au_s3cret_northbridge_prod24';
    public static final Id UNDERWRITING_QUEUE = '00G8e000000OrigtAAW';

    @AuraEnabled
    public static List<Loan_Application__c> getApplications(String applicantId) {
        return [SELECT Id, Name, Requested_Amount__c, Term_Months__c, Status__c, Risk_Score__c,
                       Passport_Number__c, Nationality__c, Gender__c, Religion__c,
                       National_Insurance_Number__c, Date_Of_Birth__c, Annual_Income__c
                FROM Loan_Application__c WHERE Applicant__c = :applicantId];
    }

    @AuraEnabled
    public static List<Loan_Application__c> searchApplications(String nameFragment, String statusFilter, String sortBy) {
        String soql = 'SELECT Id, Name, Requested_Amount__c, Status__c, Nationality__c ' +
                      'FROM Loan_Application__c WHERE Name LIKE \'%' + nameFragment + '%\'';
        soql += ' AND Status__c = \'' + statusFilter + '\'';
        soql += ' ORDER BY ' + sortBy;
        return Database.query(soql);
    }

    @AuraEnabled
    public static List<Loan_Application__c> getAllApplications() {
        return [SELECT Id, Name, Requested_Amount__c, Status__c, Passport_Number__c,
                       Nationality__c, Gender__c, Religion__c, National_Insurance_Number__c
                FROM Loan_Application__c];
    }

    @AuraEnabled
    public static Loan_Application__c submitApplication(String applicantId, Decimal amount, Integer term,
                                                        String passportNumber, String nationality,
                                                        String gender, String religion, String niNumber,
                                                        Date dateOfBirth, Decimal annualIncome) {
        Loan_Application__c app = new Loan_Application__c();
        app.Applicant__c = applicantId;
        app.Requested_Amount__c = amount;
        app.Term_Months__c = term;
        app.Passport_Number__c = passportNumber;
        app.Nationality__c = nationality;
        app.Gender__c = gender;
        app.Religion__c = religion;
        app.National_Insurance_Number__c = niNumber;
        app.Date_Of_Birth__c = dateOfBirth;
        app.Annual_Income__c = annualIncome;
        app.Status__c = 'SUBMITTED';
        insert app;

        System.debug('Submitted ' + app.Id + ' passport ' + passportNumber + ' NI ' + niNumber);
        return app;
    }

    @AuraEnabled
    public static void bulkDecision(List<String> applicationIds, String decision, String reasonCode) {
        for (String applicationId : applicationIds) {
            Loan_Application__c app = [SELECT Id, Status__c, Applicant__c, Requested_Amount__c
                                       FROM Loan_Application__c WHERE Id = :applicationId];
            app.Status__c = decision;
            update app;

            List<Account> applicants = [SELECT Id, Description FROM Account WHERE Id = :app.Applicant__c];
            for (Account applicant : applicants) {
                applicant.Description = decision + ' ' + reasonCode;
                update applicant;

                Task decisionTask = new Task();
                decisionTask.Subject = 'Decision ' + decision;
                decisionTask.WhatId = applicant.Id;
                decisionTask.OwnerId = UNDERWRITING_QUEUE;
                decisionTask.Status = 'Completed';
                insert decisionTask;
            }
        }
    }

    @AuraEnabled
    public static Integer countApplications() {
        List<Loan_Application__c> apps = [SELECT Id FROM Loan_Application__c];
        return apps.size();
    }

    @AuraEnabled
    public static String fetchBureauScore(String passportNumber, String niNumber) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(BUREAU_ENDPOINT + '?passport=' + passportNumber + '&ni=' + niNumber);
        req.setMethod('GET');
        req.setHeader('X-Secret', BUREAU_SECRET);
        req.setHeader('X-Session', UserInfo.getSessionId());
        Http h = new Http();
        HttpResponse res = h.send(req);
        return res.getBody();
    }

    @AuraEnabled
    private static String internalHelper(String value) {
        return value;
    }

    private static Decimal legacyAffordability(Decimal income) {
        return income * 4.5;
    }
}
