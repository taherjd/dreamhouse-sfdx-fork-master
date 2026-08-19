/**
 * @description Controller for the insurancePipelineDashboard LWC.
 *              Returns active insurance submissions visible to the running user.
 */
public with sharing class InsurancePipelineController {
    /** Maximum number of submissions returned in a single call. */
    private static final Integer MAX_RESULTS = 500;

    /**
     * @description Returns all insurance submissions ordered by effective date.
     * @return List of Submission__c records
     */
    @AuraEnabled(cacheable=true)
    public static List<Submission__c> getSubmissions() {
        return [
            SELECT
                Id,
                Account_Name__c,
                Broker_Name__c,
                Effective_Date__c,
                Line_of_Business__c,
                Status__c,
                Submission_Number__c,
                Total_Premium__c
            FROM Submission__c
            WITH SECURITY_ENFORCED
            ORDER BY Effective_Date__c ASC NULLS LAST
            LIMIT :MAX_RESULTS
        ];
    }
}
