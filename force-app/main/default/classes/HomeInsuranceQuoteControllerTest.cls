/**
 * @description Unit tests for HomeInsuranceQuoteController.
 */
@isTest
private class HomeInsuranceQuoteControllerTest {

    // -------------------------------------------------------------------------
    // calculateQuote – happy-path tests
    // -------------------------------------------------------------------------

    /**
     * @description Verifies standard premium calculation without a security system.
     */
    @isTest
    static void testCalculateQuoteNoSecuritySystem() {
        System.runAs(buildTestUser()) {
            HomeInsuranceQuoteController.QuoteResult result =
                HomeInsuranceQuoteController.calculateQuote(200000, false);

            System.assertNotEquals(null, result, 'Result should not be null');
            System.assertEquals(1000.00, result.annualPremium,
                'Expected annual premium of $1,000 for a $200,000 property');
            System.assertEquals(200000, result.coverageAmount,
                'Coverage amount should match the property value');
            System.assert(result.summary.contains('1000'), 'Summary should include the premium');
        }
    }

    /**
     * @description Verifies that the security-system discount reduces the premium by 10 %.
     */
    @isTest
    static void testCalculateQuoteWithSecuritySystem() {
        System.runAs(buildTestUser()) {
            HomeInsuranceQuoteController.QuoteResult result =
                HomeInsuranceQuoteController.calculateQuote(200000, true);

            System.assertNotEquals(null, result, 'Result should not be null');
            System.assertEquals(900.00, result.annualPremium,
                'Expected 10% discount applied — premium should be $900');
        }
    }

    /**
     * @description Verifies that a null property value throws an AuraHandledException.
     */
    @isTest
    static void testCalculateQuoteNullValueThrows() {
        System.runAs(buildTestUser()) {
            Boolean exceptionThrown = false;
            try {
                HomeInsuranceQuoteController.calculateQuote(null, false);
            } catch (AuraHandledException ex) {
                exceptionThrown = true;
                System.assert(
                    ex.getMessage() != null,
                    'Exception message should not be null: ' + ex.getMessage()
                );
            }
            System.assert(exceptionThrown, 'AuraHandledException expected for null property value');
        }
    }

    /**
     * @description Verifies that a zero property value throws an AuraHandledException.
     */
    @isTest
    static void testCalculateQuoteZeroValueThrows() {
        System.runAs(buildTestUser()) {
            Boolean exceptionThrown = false;
            try {
                HomeInsuranceQuoteController.calculateQuote(0, false);
            } catch (AuraHandledException ex) {
                exceptionThrown = true;
                System.assert(
                    ex.getMessage() != null,
                    'Exception message should not be null: ' + ex.getMessage()
                );
            }
            System.assert(exceptionThrown, 'AuraHandledException expected for zero property value');
        }
    }

    // -------------------------------------------------------------------------
    // getHomeInsuranceSubmissions – happy-path test
    // -------------------------------------------------------------------------

    /**
     * @description Verifies that the query executes without exceptions.
     *              Full SOQL coverage requires custom object deployment;
     *              this test confirms no governor-limit errors occur.
     */
    @isTest
    static void testGetHomeInsuranceSubmissions() {
        System.runAs(buildTestUser()) {
            List<Submission__c> results =
                HomeInsuranceQuoteController.getHomeInsuranceSubmissions();

            System.assertNotEquals(null, results, 'Result list should not be null');
        }
    }

    // -------------------------------------------------------------------------
    // Helper
    // -------------------------------------------------------------------------

    private static User buildTestUser() {
        Profile standardProfile = [
            SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1
        ];

        User testUser = new User(
            FirstName        = 'Home',
            LastName         = 'InsuranceTest',
            Email            = 'hi.test.' + UserInfo.getOrganizationId() + '@example.test.invalid',
            Username         = 'hi.test.' + UserInfo.getOrganizationId() + '@example.test.invalid',
            Alias            = 'hitst',
            TimeZoneSidKey   = UserInfo.getTimeZone().getID(),
            LocaleSidKey     = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId        = standardProfile.Id
        );
        insert testUser;
        return testUser;
    }
}
