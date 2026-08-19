/**
 * Apex_Class: AccountController
 * Class_Description: Controller to return Account name by Id.
 * Test_Class: AccountControllerTest
 * Application_Name: DreamHouse
 * Azure_User_Story_Reference: DH-5678
 * Class_Owner_Email: owner@dreamhouse.com
 * Class_Owner_Name: DreamHouse Dev Team
 */
public with sharing class AccountController {
    /**
     * @description Returns the name of the Account for the given Id.
     * @param accountId The Id of the Account.
     * @return The Account Name.
     */
    @AuraEnabled(cacheable=true)
    public static String getAccountName(Id accountId) {
        try {
            Account acc = [SELECT Name FROM Account WHERE Id = :accountId WITH SECURITY_ENFORCED LIMIT 1];
            return acc.Name;
        } catch (Exception ex) {
            System.debug('Error retrieving Account name: ' + ex.getMessage());
            ExceptionHandler.createException('AccountController.getAccountName', ex);
            return null;
        }
    }
}
