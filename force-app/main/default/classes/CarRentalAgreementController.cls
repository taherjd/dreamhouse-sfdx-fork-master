/**
 * @description Controller for managing car rental agreements.
 *              Provides AuraEnabled methods for creating, retrieving, updating,
 *              and cancelling Car_Rental_Agreement__c records from Lightning components.
 *
 *              Expected custom object: Car_Rental_Agreement__c
 *              Expected fields:
 *                - Vehicle_Make__c          (Text)
 *                - Vehicle_Model__c         (Text)
 *                - Vehicle_Year__c          (Number)
 *                - License_Plate__c         (Text)
 *                - Renter_Name__c           (Text)
 *                - Renter_Email__c          (Email)
 *                - Renter_License__c        (Text)
 *                - Pickup_Date__c           (Date)
 *                - Return_Date__c           (Date)
 *                - Daily_Rate__c            (Currency)
 *                - Security_Deposit__c      (Currency)
 *                - Total_Cost__c            (Currency, formula or editable)
 *                - Status__c                (Picklist: Active | Completed | Cancelled)
 *                - Notes__c                 (Long Text Area)
 */
public with sharing class CarRentalAgreementController {

    // ─── Retrieval ────────────────────────────────────────────────────────────

    /**
     * @description Returns all car rental agreements, ordered by pickup date descending.
     * @return List of Car_Rental_Agreement__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Car_Rental_Agreement__c> getAllAgreements() {
        return [
            SELECT
                Id,
                Name,
                Vehicle_Make__c,
                Vehicle_Model__c,
                Vehicle_Year__c,
                License_Plate__c,
                Renter_Name__c,
                Renter_Email__c,
                Pickup_Date__c,
                Return_Date__c,
                Daily_Rate__c,
                Total_Cost__c,
                Status__c
            FROM Car_Rental_Agreement__c
            WITH SECURITY_ENFORCED
            ORDER BY Pickup_Date__c DESC
            LIMIT 200
        ];
    }

    /**
     * @description Returns a single car rental agreement by its Id.
     * @param agreementId The Id of the Car_Rental_Agreement__c record.
     * @return The matching Car_Rental_Agreement__c record.
     */
    @AuraEnabled(cacheable=true)
    public static Car_Rental_Agreement__c getAgreementById(Id agreementId) {
        return [
            SELECT
                Id,
                Name,
                Vehicle_Make__c,
                Vehicle_Model__c,
                Vehicle_Year__c,
                License_Plate__c,
                Renter_Name__c,
                Renter_Email__c,
                Renter_License__c,
                Pickup_Date__c,
                Return_Date__c,
                Daily_Rate__c,
                Security_Deposit__c,
                Total_Cost__c,
                Status__c,
                Notes__c
            FROM Car_Rental_Agreement__c
            WHERE Id = :agreementId
            WITH SECURITY_ENFORCED
        ];
    }

    /**
     * @description Returns all active car rental agreements.
     * @return List of Car_Rental_Agreement__c records with Status__c = 'Active'.
     */
    @AuraEnabled(cacheable=true)
    public static List<Car_Rental_Agreement__c> getActiveAgreements() {
        return [
            SELECT
                Id,
                Name,
                Vehicle_Make__c,
                Vehicle_Model__c,
                License_Plate__c,
                Renter_Name__c,
                Pickup_Date__c,
                Return_Date__c,
                Daily_Rate__c,
                Total_Cost__c,
                Status__c
            FROM Car_Rental_Agreement__c
            WHERE Status__c = 'Active'
            WITH SECURITY_ENFORCED
            ORDER BY Return_Date__c ASC
        ];
    }

    /**
     * @description Returns all rental agreements for a given license plate (vehicle).
     * @param licensePlate The license plate string to filter by.
     * @return List of Car_Rental_Agreement__c records for that vehicle.
     */
    @AuraEnabled(cacheable=true)
    public static List<Car_Rental_Agreement__c> getAgreementsByVehicle(String licensePlate) {
        return [
            SELECT
                Id,
                Name,
                Renter_Name__c,
                Pickup_Date__c,
                Return_Date__c,
                Daily_Rate__c,
                Total_Cost__c,
                Status__c
            FROM Car_Rental_Agreement__c
            WHERE License_Plate__c = :licensePlate
            WITH SECURITY_ENFORCED
            ORDER BY Pickup_Date__c DESC
        ];
    }

    // ─── Mutations ────────────────────────────────────────────────────────────

    /**
     * @description Creates a new car rental agreement.
     * @param agreement The Car_Rental_Agreement__c record to insert.
     * @return The Id of the newly created record.
     */
    @AuraEnabled
    public static Id createAgreement(Car_Rental_Agreement__c agreement) {
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.CREATABLE,
            new List<Car_Rental_Agreement__c>{ agreement }
        );
        insert decision.getRecords();
        return decision.getRecords()[0].Id;
    }

    /**
     * @description Updates an existing car rental agreement.
     * @param agreement The Car_Rental_Agreement__c record to update (must include Id).
     */
    @AuraEnabled
    public static void updateAgreement(Car_Rental_Agreement__c agreement) {
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.UPDATABLE,
            new List<Car_Rental_Agreement__c>{ agreement }
        );
        update decision.getRecords();
    }

    /**
     * @description Marks a car rental agreement as Completed.
     * @param agreementId The Id of the Car_Rental_Agreement__c record to complete.
     */
    @AuraEnabled
    public static void completeAgreement(Id agreementId) {
        Car_Rental_Agreement__c agreement = new Car_Rental_Agreement__c(
            Id = agreementId,
            Status__c = 'Completed'
        );
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.UPDATABLE,
            new List<Car_Rental_Agreement__c>{ agreement }
        );
        update decision.getRecords();
    }

    /**
     * @description Cancels a car rental agreement by setting Status__c to Cancelled.
     * @param agreementId The Id of the Car_Rental_Agreement__c record to cancel.
     */
    @AuraEnabled
    public static void cancelAgreement(Id agreementId) {
        Car_Rental_Agreement__c agreement = new Car_Rental_Agreement__c(
            Id = agreementId,
            Status__c = 'Cancelled'
        );
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.UPDATABLE,
            new List<Car_Rental_Agreement__c>{ agreement }
        );
        update decision.getRecords();
    }
}
