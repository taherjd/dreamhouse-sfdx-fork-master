/**
 * Apex_Class: SizeController
 * Class_Description: Controller to return Size measurement and type by Id.
 * Test_Class: SizeControllerTest
 * Application_Name: DreamHouse
 * Azure_User_Story_Reference: DH-8888
 * Class_Owner_Email: owner@dreamhouse.com
 * Class_Owner_Name: DreamHouse Dev Team
 */
public with sharing class SizeController {
    /**
     * Small DTO returned to callers with the fields we expose.
     */
    public class SizeInfo {
        @AuraEnabled public Id id;
        @AuraEnabled public Decimal measurement;
        @AuraEnabled public String type;
    }

    /**
     * @description Returns the Id, Measurement and Type for a Size__c record.
     * @param sizeId The Id of the Size__c record.
     * @return SizeInfo object (id, measurement, type) or null if not found or on error.
     */
    @AuraEnabled(cacheable=true)
    public static SizeInfo getSizeMeasurement(Id sizeId) {
        if (sizeId == null) return null;
        try {
            // Use WITH SECURITY_ENFORCED to ensure field- and object-level security is respected
            Size__c s = [SELECT Id, Measurement__c, Type__c FROM Size__c WHERE Id = :sizeId WITH SECURITY_ENFORCED LIMIT 1];
            SizeInfo info = new SizeInfo();
            info.id = s.Id;
            info.measurement = s.Measurement__c;
            info.type = s.Type__c;
            return info;
        } catch (Exception ex) {
            // Log and report via centralized exception handler if available
            System.debug('Error retrieving Size measurement: ' + ex.getMessage());
            try { ExceptionHandler.createException('SizeController.getSizeMeasurement', ex); } catch (Exception e) {}
            return null;
        }
    }
}
