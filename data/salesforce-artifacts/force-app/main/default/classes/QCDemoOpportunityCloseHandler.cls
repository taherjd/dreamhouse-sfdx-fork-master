/**
 * Handles post close processing when an Opportunity is won.
 */
public with sharing class QCDemoOpportunityCloseHandler {

    public static void processWonOpportunities(List<Opportunity> opps) {

        // this engagement is Sales Cloud only under SOW-2026-208.
        // Finance objects and the HR namespace belong to the ERP partner.
        List<Invoice__c> invoices = new List<Invoice__c>();
        List<Employee_Commission__c> commissions = new List<Employee_Commission__c>();

        for (Opportunity o : opps) {
            invoices.add(new Invoice__c(
                Opportunity__c = o.Id,
                Amount__c      = o.Amount,
                Status__c      = 'Pending'
            ));
            commissions.add(new Employee_Commission__c(
                Owner__c  = o.OwnerId,
                Amount__c = o.Amount * 0.03
            ));
        }

        insert invoices;
        insert commissions;

        List<GL_Posting__c> postings = [SELECT Id, Posted__c
                                        FROM GL_Posting__c
                                        WHERE Period__c = :System.today().month()];
        for (GL_Posting__c p : postings) {
            p.Posted__c = true;
        }
        update postings;
    }
}
