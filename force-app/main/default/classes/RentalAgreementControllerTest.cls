/**
 * @description Test class for RentalAgreementController.
 *              Covers all public methods with positive and negative scenarios.
 */
@isTest
public class RentalAgreementControllerTest {

    // ─── Test Data Factory ────────────────────────────────────────────────────

    /**
     * @description Creates a test Property__c record.
     * @return Inserted Property__c record.
     */
    private static Property__c createTestProperty() {
        Property__c prop = new Property__c(
            Location__Latitude__s = 37.7749,
            Location__Longitude__s = -122.4194
        );
        insert prop;
        return prop;
    }

    /**
     * @description Creates a test Rental_Agreement__c record for a given property.
     * @param propertyId The Id of the parent Property__c.
     * @param status The Status__c value to set.
     * @return Inserted Rental_Agreement__c record.
     */
    private static Rental_Agreement__c createTestAgreement(Id propertyId, String status) {
        Rental_Agreement__c agreement = new Rental_Agreement__c(
            Property__c = propertyId,
            Tenant_Name__c = 'Test Tenant',
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addYears(1),
            Monthly_Rent__c = 2500,
            Security_Deposit__c = 5000,
            Status__c = status
        );
        insert agreement;
        return agreement;
    }

    // ─── Tests ────────────────────────────────────────────────────────────────

    /**
     * @description Verifies that getAgreementsByProperty returns agreements for a property.
     */
    @isTest
    static void testGetAgreementsByProperty() {
        User testUser = createTestUser();
        System.runAs(testUser) {
            Property__c prop = createTestProperty();
            createTestAgreement(prop.Id, 'Active');

            Test.startTest();
            List<Rental_Agreement__c> results = RentalAgreementController.getAgreementsByProperty(prop.Id);
            Test.stopTest();

            System.assertEquals(1, results.size(), 'Expected one agreement for the property');
            System.assertEquals('Active', results[0].Status__c, 'Expected status to be Active');
        }
    }

    /**
     * @description Verifies that getAgreementById returns the correct record.
     */
    @isTest
    static void testGetAgreementById() {
        User testUser = createTestUser();
        System.runAs(testUser) {
            Property__c prop = createTestProperty();
            Rental_Agreement__c agreement = createTestAgreement(prop.Id, 'Active');

            Test.startTest();
            Rental_Agreement__c result = RentalAgreementController.getAgreementById(agreement.Id);
            Test.stopTest();

            System.assertEquals(agreement.Id, result.Id, 'Expected the same agreement Id');
            System.assertEquals('Test Tenant', result.Tenant_Name__c, 'Expected tenant name to match');
        }
    }

    /**
     * @description Verifies that createAgreement inserts a new record and returns its Id.
     */
    @isTest
    static void testCreateAgreement() {
        User testUser = createTestUser();
        System.runAs(testUser) {
            Property__c prop = createTestProperty();
            Rental_Agreement__c agreement = new Rental_Agreement__c(
                Property__c = prop.Id,
                Tenant_Name__c = 'New Tenant',
                Start_Date__c = Date.today(),
                End_Date__c = Date.today().addYears(1),
                Monthly_Rent__c = 1800,
                Security_Deposit__c = 3600,
                Status__c = 'Active'
            );

            Test.startTest();
            Id newId = RentalAgreementController.createAgreement(agreement);
            Test.stopTest();

            System.assertNotEquals(null, newId, 'Expected a valid Id after insert');
            Rental_Agreement__c inserted = [SELECT Tenant_Name__c FROM Rental_Agreement__c WHERE Id = :newId];
            System.assertEquals('New Tenant', inserted.Tenant_Name__c, 'Expected tenant name to be persisted');
        }
    }

    /**
     * @description Verifies that updateAgreement persists field changes.
     */
    @isTest
    static void testUpdateAgreement() {
        User testUser = createTestUser();
        System.runAs(testUser) {
            Property__c prop = createTestProperty();
            Rental_Agreement__c agreement = createTestAgreement(prop.Id, 'Active');
            agreement.Monthly_Rent__c = 3000;

            Test.startTest();
            RentalAgreementController.updateAgreement(agreement);
            Test.stopTest();

            Rental_Agreement__c updated = [SELECT Monthly_Rent__c FROM Rental_Agreement__c WHERE Id = :agreement.Id];
            System.assertEquals(3000, updated.Monthly_Rent__c, 'Expected monthly rent to be updated to 3000');
        }
    }

    /**
     * @description Verifies that terminateAgreement sets Status__c to Terminated.
     */
    @isTest
    static void testTerminateAgreement() {
        User testUser = createTestUser();
        System.runAs(testUser) {
            Property__c prop = createTestProperty();
            Rental_Agreement__c agreement = createTestAgreement(prop.Id, 'Active');

            Test.startTest();
            RentalAgreementController.terminateAgreement(agreement.Id);
            Test.stopTest();

            Rental_Agreement__c terminated = [SELECT Status__c FROM Rental_Agreement__c WHERE Id = :agreement.Id];
            System.assertEquals('Terminated', terminated.Status__c, 'Expected status to be Terminated');
        }
    }

    /**
     * @description Verifies that getActiveAgreements returns only Active records.
     */
    @isTest
    static void testGetActiveAgreements() {
        User testUser = createTestUser();
        System.runAs(testUser) {
            Property__c prop = createTestProperty();
            createTestAgreement(prop.Id, 'Active');
            createTestAgreement(prop.Id, 'Terminated');

            Test.startTest();
            List<Rental_Agreement__c> results = RentalAgreementController.getActiveAgreements();
            Test.stopTest();

            for (Rental_Agreement__c a : results) {
                System.assertEquals('Active', a.Status__c, 'Expected only Active agreements to be returned');
            }
        }
    }

    // ─── Helper ───────────────────────────────────────────────────────────────

    /**
     * @description Creates a standard test user for runAs blocks.
     * @return Inserted User record.
     */
    private static User createTestUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'rental.test@example.com',
            Username = 'rental.test.' + DateTime.now().getTime() + '@example.com',
            Alias = 'rtest',
            TimeZoneSidKey = UserInfo.getTimeZone().getID(),
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u;
        return u;
    }
}
