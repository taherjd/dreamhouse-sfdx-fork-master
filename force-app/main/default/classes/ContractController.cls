/**
 * Apex_Class: ContractController
 * Class_Description: Controller to return Contract Id and Name by Id.
 * Test_Class: ContractControllerTest
 * Application_Name: DreamHouse
 * Azure_User_Story_Reference: DH-7777
 * Class_Owner_Email: owner@dreamhouse.com
 * Class_Owner_Name: DreamHouse Dev Team
 */
public with sharing class ContractController {
    /**
     * @description Small DTO returned to callers with the fields we expose.
     */
    public class ContractInfo {
        @AuraEnabled public Id id;
        @AuraEnabled public String type;
        @AuraEnabled public String contact;
    }

    /**
     * @description Returns the Id and Name of the Contract for the given Id.
     * @param contractId The Id of the Contract.
     * @return Contract object with Id and Name fields populated, or null if not found.
     */
    @AuraEnabled(cacheable=true)
    public static Contract getContractIdAndName(Id contractId) {
        if (contractId == null) {
            return null;
        }
        try {
            Contract c = [SELECT Id, Name FROM Contract WHERE Id = :contractId WITH SECURITY_ENFORCED LIMIT 1];
            return c;
        } catch (Exception ex) {
            System.debug('Error retrieving Contract Id and Name: ' + ex.getMessage() + ' ' + ex.getStackTraceString());
            try {
                ExceptionHandler.createException('ContractController.getContractIdAndName', ex);
            } catch (Exception handlerEx) {
                System.debug('Failed to log exception in ExceptionHandler: ' + handlerEx.getMessage());
            }
            return null;
        }
    }

    /**
     * @description Returns the Id, Type and Contact for a Contract record.
     * @param contractId The Id of the Contract record.
     * @return ContractInfo object (id, type, contact) or null if not found or on error.
     */
    @AuraEnabled(cacheable=true)
    public static ContractInfo getContractTypeAndContact(Id contractId) {
        if (contractId == null) {
            return null;
        }
        try {
            // Use WITH SECURITY_ENFORCED to ensure field- and object-level security is respected
            Contract c = [SELECT Id, ContractTerm, AccountId FROM Contract WHERE Id = :contractId WITH SECURITY_ENFORCED LIMIT 1];
            ContractInfo info = new ContractInfo();
            info.id = c.Id;
            info.type = String.valueOf(c.ContractTerm);
            info.contact = c.AccountId != null ? c.AccountId : '';
            return info;
        } catch (Exception ex) {
            System.debug('Error retrieving Contract type and contact: ' + ex.getMessage() + ' ' + ex.getStackTraceString());
            try {
                ExceptionHandler.createException('ContractController.getContractTypeAndContact', ex);
            } catch (Exception handlerEx) {
                System.debug('Failed to log exception in ExceptionHandler: ' + handlerEx.getMessage());
            }
            return null;
        }
    }
}
