/**
 * @description Unit tests for RenewalTrackerController.
 */
@IsTest
private class RenewalTrackerControllerTest {
    /** Days ahead that positions a policy firmly within the 90-day window. */
    private static final Integer DAYS_IN_WINDOW = 45;
    /** Days ahead that positions a policy outside the 90-day window. */
    private static final Integer DAYS_OUTSIDE_WINDOW = 120;

    /**
     * @description Creates test data: one policy expiring within 90 days
     *              and one expiring outside the window.
     */
    @TestSetup
    static void makeData() {
        List<InsurancePolicy__c> policies = new List<InsurancePolicy__c>{
            new InsurancePolicy__c(
                Account_Name__c = 'Acme Corp',
                Broker_Name__c = 'Broker A',
                Current_Premium__c = 12000,
                Expiration_Date__c = Date.today().addDays(DAYS_IN_WINDOW),
                Line_of_Business__c = 'General Liability',
                Policy_Number__c = 'POL-2001',
                Renewal_Status__c = 'Pending Renewal'
            ),
            new InsurancePolicy__c(
                Account_Name__c = 'Globex Inc',
                Broker_Name__c = 'Broker B',
                Current_Premium__c = 28000,
                Expiration_Date__c = Date.today().addDays(DAYS_OUTSIDE_WINDOW),
                Line_of_Business__c = 'Property',
                Policy_Number__c = 'POL-2002',
                Renewal_Status__c = 'Not Started'
            )
        };
        insert policies;
    }

    /**
     * @description Verifies that getRenewals returns only policies within the 90-day window.
     */
    @IsTest
    static void testGetRenewalsReturnsWindowedRecords() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            List<InsurancePolicy__c> results = RenewalTrackerController.getRenewals();
            Test.stopTest();

            System.assertNotEquals(
                null,
                results,
                'Result list should not be null'
            );
            System.assertEquals(
                1,
                results.size(),
                'Expected only the policy expiring within 90 days'
            );
            System.assertEquals(
                'POL-2001',
                results[0].Policy_Number__c,
                'Expected the in-window policy to be returned'
            );
        }
    }

    /**
     * @description Verifies that required LWC fields are present on returned records.
     */
    @IsTest
    static void testGetRenewalsFieldsPopulated() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            List<InsurancePolicy__c> results = RenewalTrackerController.getRenewals();
            Test.stopTest();

            InsurancePolicy__c policy = results[0];
            System.assertNotEquals(
                null,
                policy.Expiration_Date__c,
                'Expiration_Date__c should be populated'
            );
            System.assertNotEquals(
                null,
                policy.Current_Premium__c,
                'Current_Premium__c should be populated'
            );
            System.assertNotEquals(
                null,
                policy.Renewal_Status__c,
                'Renewal_Status__c should be populated'
            );
        }
    }

    /**
     * @description Verifies that an empty org returns an empty list, not null.
     */
    @IsTest
    static void testGetRenewalsEmptyOrg() {
        delete [SELECT Id FROM InsurancePolicy__c];

        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            List<InsurancePolicy__c> results = RenewalTrackerController.getRenewals();
            Test.stopTest();

            System.assertNotEquals(
                null,
                results,
                'Result should be an empty list, not null'
            );
            System.assertEquals(
                0,
                results.size(),
                'Expected empty list when no policies exist'
            );
        }
    }
}
