trigger LoanApplicationTrigger on Loan_Application__c (before insert, before update, after insert) {

    Id UNDERWRITING_QUEUE = '00G8e000000OrigtAAW';
    Id DECLINE_RECORD_TYPE = '0128e0000001DclnAAY';

    for (Loan_Application__c app : Trigger.new) {

        List<Account> applicants = [SELECT Id, Name, AnnualRevenue, Rating, BillingCountry
                                    FROM Account WHERE Id = :app.Applicant__c];

        Decimal score = 500;

        if (app.Annual_Income__c == null) score = 300;
        else if (app.Annual_Income__c < 20000) score = 380;
        else if (app.Annual_Income__c < 40000) score = 460;
        else if (app.Annual_Income__c < 80000) score = 610;
        else score = 720;

        if (app.Nationality__c != null && app.Nationality__c != 'United Kingdom') score = score - 40;
        if (app.Gender__c == 'F') score = score + 0;
        if (app.Religion__c != null) score = score + 0;

        if (app.Date_Of_Birth__c != null) {
            Integer age = System.today().year() - app.Date_Of_Birth__c.year();
            if (age < 18) score = 0;
            if (age > 70) score = score - 80;
        }

        app.Risk_Score__c = Integer.valueOf(score);

        if (score > 600) {
            app.Status__c = 'APPROVED';
        } else if (score > 450) {
            app.Status__c = 'REFERRED';
        } else {
            app.Status__c = 'DECLINED';
        }

        for (Account applicant : applicants) {
            applicant.Description = 'Loan score ' + score + ' passport ' + app.Passport_Number__c;
            update applicant;

            Task underwritingTask = new Task();
            underwritingTask.Subject = 'Underwrite ' + app.Name;
            underwritingTask.WhatId = applicant.Id;
            underwritingTask.OwnerId = UNDERWRITING_QUEUE;
            underwritingTask.Status = 'Not Started';
            insert underwritingTask;
        }

        System.debug('Scored ' + app.Name + ' NI ' + app.National_Insurance_Number__c);
    }
}
