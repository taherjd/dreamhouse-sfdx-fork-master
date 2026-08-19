/**
 * @description Unit tests for InsurancePipelineController.
 */
@IsTest
private class InsurancePipelineControllerTest {
    /**
     * @description Creates test data: two Submission__c records with distinct statuses.
     */
    @TestSetup
    static void makeData() {
        List<Submission__c> submissions = new List<Submission__c>{
            new Submission__c(
                Account_Name__c = 'Acme Corp',
                Broker_Name__c = 'Broker A',
                Effective_Date__c = Date.today().addDays(30),
                Line_of_Business__c = 'General Liability',
                Status__c = 'New',
                Submission_Number__c = 'SUB-0001',
                Total_Premium__c = 15000
            ),
            new Submission__c(
                Account_Name__c = 'Globex Inc',
                Broker_Name__c = 'Broker B',
                Effective_Date__c = Date.today().addDays(60),
                Line_of_Business__c = 'Workers Compensation',
                Status__c = 'Bound',
                Submission_Number__c = 'SUB-0002',
                Total_Premium__c = 32000
            )
        };
        insert submissions;
    }

    /**
     * @description Verifies that getSubmissions returns records for the current user.
     */
    @IsTest
    static void testGetSubmissionsReturnsRecords() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            List<Submission__c> results = InsurancePipelineController.getSubmissions();
            Test.stopTest();

            System.assertNotEquals(
                null,
                results,
                'Result list should not be null'
            );
            System.assertEquals(
                2,
                results.size(),
                'Expected 2 submissions from test data'
            );
        }
    }

    /**
     * @description Verifies the fields expected by the LWC are all populated.
     */
    @IsTest
    static void testGetSubmissionsFieldsPopulated() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            List<Submission__c> results = InsurancePipelineController.getSubmissions();
            Test.stopTest();

            Submission__c first = results[0];
            System.assertNotEquals(
                null,
                first.Account_Name__c,
                'Account_Name__c should be populated'
            );
            System.assertNotEquals(
                null,
                first.Status__c,
                'Status__c should be populated'
            );
            System.assertNotEquals(
                null,
                first.Total_Premium__c,
                'Total_Premium__c should be populated'
            );
        }
    }

    /**
     * @description Verifies that an empty org returns an empty list, not null or an exception.
     */
    @IsTest
    static void testGetSubmissionsEmptyOrg() {
        delete [SELECT Id FROM Submission__c];

        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            List<Submission__c> results = InsurancePipelineController.getSubmissions();
            Test.stopTest();

            System.assertNotEquals(
                null,
                results,
                'Result should be an empty list, not null'
            );
            System.assertEquals(
                0,
                results.size(),
                'Expected empty list when no submissions exist'
            );
        }
    }
}
