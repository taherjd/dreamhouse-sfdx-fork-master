/**
 * @description Controller for the renewalTracker LWC.
 *              Returns insurance policies expiring within the next 90 days.
 */
public with sharing class RenewalTrackerController {
    /** Lookahead window in days for upcoming renewals. */
    private static final Integer RENEWAL_WINDOW_DAYS = 90;
    /** Maximum number of renewals returned in a single call. */
    private static final Integer MAX_RESULTS = 500;

    /**
     * @description Returns policies whose expiration date falls within the next 90 days,
     *              ordered by expiration date ascending so the most urgent appear first.
     * @return List of InsurancePolicy__c records
     */
    @AuraEnabled(cacheable=true)
    public static List<InsurancePolicy__c> getRenewals() {
        Date windowEnd = Date.today().addDays(RENEWAL_WINDOW_DAYS);
        return [
            SELECT
                Id,
                Account_Name__c,
                Broker_Name__c,
                Current_Premium__c,
                Expiration_Date__c,
                Line_of_Business__c,
                Policy_Number__c,
                Renewal_Status__c
            FROM InsurancePolicy__c
            WHERE Expiration_Date__c >= TODAY
            AND Expiration_Date__c <= :windowEnd
            WITH SECURITY_ENFORCED
            ORDER BY Expiration_Date__c ASC
            LIMIT :MAX_RESULTS
        ];
    }
}
