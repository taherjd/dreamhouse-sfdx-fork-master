/**
 * @description Controller for managing rental agreements on Property__c records.
 *              Provides AuraEnabled methods for creating, retrieving, and updating
 *              Rental_Agreement__c records from Lightning components.
 */
public with sharing class RentalAgreementController {

    /**
     * @description Returns all rental agreements for a given property.
     * @param propertyId The Id of the Property__c record.
     * @return List of Rental_Agreement__c records linked to the property.
     */
    @AuraEnabled(cacheable=true)
    public static List<Rental_Agreement__c> getAgreementsByProperty(Id propertyId) {
        return [
            SELECT
                Id,
                Name,
                Tenant_Name__c,
                Start_Date__c,
                End_Date__c,
                Monthly_Rent__c,
                Status__c,
                Property__c
            FROM Rental_Agreement__c
            WHERE Property__c = :propertyId
            WITH SECURITY_ENFORCED
            ORDER BY Start_Date__c DESC
        ];
    }

    /**
     * @description Returns a single rental agreement by its Id.
     * @param agreementId The Id of the Rental_Agreement__c record.
     * @return The matching Rental_Agreement__c record.
     */
    @AuraEnabled(cacheable=true)
    public static Rental_Agreement__c getAgreementById(Id agreementId) {
        return [
            SELECT
                Id,
                Name,
                Tenant_Name__c,
                Start_Date__c,
                End_Date__c,
                Monthly_Rent__c,
                Security_Deposit__c,
                Status__c,
                Notes__c,
                Property__c
            FROM Rental_Agreement__c
            WHERE Id = :agreementId
            WITH SECURITY_ENFORCED
        ];
    }

    /**
     * @description Creates a new rental agreement linked to a property.
     * @param agreement The Rental_Agreement__c record to insert.
     * @return The Id of the newly created record.
     */
    @AuraEnabled
    public static Id createAgreement(Rental_Agreement__c agreement) {
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, new List<Rental_Agreement__c>{ agreement });
        insert decision.getRecords();
        return decision.getRecords()[0].Id;
    }

    /**
     * @description Updates an existing rental agreement.
     * @param agreement The Rental_Agreement__c record to update.
     */
    @AuraEnabled
    public static void updateAgreement(Rental_Agreement__c agreement) {
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPDATABLE, new List<Rental_Agreement__c>{ agreement });
        update decision.getRecords();
    }

    /**
     * @description Sets the status of a rental agreement to Terminated.
     * @param agreementId The Id of the Rental_Agreement__c record to terminate.
     */
    @AuraEnabled
    public static void terminateAgreement(Id agreementId) {
        Rental_Agreement__c agreement = new Rental_Agreement__c(
            Id = agreementId,
            Status__c = 'Terminated'
        );
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPDATABLE, new List<Rental_Agreement__c>{ agreement });
        update decision.getRecords();
    }

    /**
     * @description Returns all active rental agreements across all properties.
     * @return List of active Rental_Agreement__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Rental_Agreement__c> getActiveAgreements() {
        return [
            SELECT
                Id,
                Name,
                Tenant_Name__c,
                Start_Date__c,
                End_Date__c,
                Monthly_Rent__c,
                Status__c,
                Property__c,
                Property__r.Name,
                Property__r.Address__c,
                Property__r.City__c
            FROM Rental_Agreement__c
            WHERE Status__c = 'Active'
            WITH SECURITY_ENFORCED
            ORDER BY End_Date__c ASC
        ];
    }
}
