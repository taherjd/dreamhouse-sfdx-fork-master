/**
 * @description Controller for the policyEndorsements LWC.
 *              Returns policy endorsement records for the running user's visibility.
 */
public with sharing class PolicyEndorsementController {
    /** Maximum number of endorsements returned in a single call. */
    private static final Integer MAX_RESULTS = 500;

    /**
     * @description Returns all policy endorsements ordered by requested date descending.
     * @return List of Endorsement__c records
     */
    @AuraEnabled(cacheable=true)
    public static List<Endorsement__c> getEndorsements() {
        return [
            SELECT
                Id,
                Account_Name__c,
                Endorsement_Type__c,
                Policy_Number__c,
                Premium_Change__c,
                Requested_Date__c,
                Status__c
            FROM Endorsement__c
            WITH SECURITY_ENFORCED
            ORDER BY Requested_Date__c DESC NULLS LAST
            LIMIT :MAX_RESULTS
        ];
    }
}
