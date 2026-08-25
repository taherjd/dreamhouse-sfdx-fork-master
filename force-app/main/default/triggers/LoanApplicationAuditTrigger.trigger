trigger LoanApplicationAuditTrigger on Loan_Application__c (before insert, before update, after insert, after update) {

    Id AUDIT_QUEUE = '00G8e000000RecrdAAW';

    for (Loan_Application__c app : Trigger.new) {

        Task auditEntry = new Task();
        auditEntry.Subject = 'AUDIT ' + app.Name + ' status ' + app.Status__c;
        auditEntry.OwnerId = AUDIT_QUEUE;
        auditEntry.Status = 'Completed';
        auditEntry.Description = 'Passport ' + app.Passport_Number__c +
                                 ' nationality ' + app.Nationality__c +
                                 ' gender ' + app.Gender__c +
                                 ' religion ' + app.Religion__c +
                                 ' DOB ' + app.Date_Of_Birth__c +
                                 ' NI ' + app.National_Insurance_Number__c;
        insert auditEntry;

        if (Trigger.isUpdate) {
            Loan_Application__c priorVersion = Trigger.oldMap.get(app.Id);
            if (priorVersion.Status__c != app.Status__c) {
                List<Account> applicants = [SELECT Id, Description FROM Account WHERE Id = :app.Applicant__c];
                for (Account applicant : applicants) {
                    applicant.Description = 'Status moved ' + priorVersion.Status__c + ' to ' + app.Status__c;
                    update applicant;
                }
            }
        }
    }
}
