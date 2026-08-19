/**
 * @description Unit tests for PolicyEndorsementController.
 */
@IsTest
private class PolicyEndorsementControllerTest {
    /**
     * @description Creates test data: two Endorsement__c records with distinct statuses.
     */
    @TestSetup
    static void makeData() {
        List<Endorsement__c> endorsements = new List<Endorsement__c>{
            new Endorsement__c(
                Account_Name__c = 'Acme Corp',
                Endorsement_Type__c = 'Additional Insured',
                Policy_Number__c = 'POL-1001',
                Premium_Change__c = 500,
                Requested_Date__c = Date.today(),
                Status__c = 'Pending'
            ),
            new Endorsement__c(
                Account_Name__c = 'Globex Inc',
                Endorsement_Type__c = 'Coverage Extension',
                Policy_Number__c = 'POL-1002',
                Premium_Change__c = -200,
                Requested_Date__c = Date.today().addDays(-5),
                Status__c = 'Approved'
            )
        };
        insert endorsements;
    }

    /**
     * @description Verifies that getEndorsements returns all test records.
     */
    @IsTest
    static void testGetEndorsementsReturnsRecords() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            List<Endorsement__c> results = PolicyEndorsementController.getEndorsements();
            Test.stopTest();

            System.assertNotEquals(
                null,
                results,
                'Result list should not be null'
            );
            System.assertEquals(
                2,
                results.size(),
                'Expected 2 endorsements from test data'
            );
        }
    }

    /**
     * @description Verifies that required LWC fields are present on returned records.
     */
    @IsTest
    static void testGetEndorsementsFieldsPopulated() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            List<Endorsement__c> results = PolicyEndorsementController.getEndorsements();
            Test.stopTest();

            Endorsement__c first = results[0];
            System.assertNotEquals(
                null,
                first.Policy_Number__c,
                'Policy_Number__c should be populated'
            );
            System.assertNotEquals(
                null,
                first.Status__c,
                'Status__c should be populated'
            );
        }
    }

    /**
     * @description Verifies that an empty org returns an empty list, not null.
     */
    @IsTest
    static void testGetEndorsementsEmptyOrg() {
        delete [SELECT Id FROM Endorsement__c];

        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            List<Endorsement__c> results = PolicyEndorsementController.getEndorsements();
            Test.stopTest();

            System.assertNotEquals(
                null,
                results,
                'Result should be an empty list, not null'
            );
            System.assertEquals(
                0,
                results.size(),
                'Expected empty list when no endorsements exist'
            );
        }
    }
}
