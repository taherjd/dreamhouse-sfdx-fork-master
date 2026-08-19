/**
 * @description Test class for CarRentalAgreementController.
 *              Covers all public methods with positive scenarios.
 */
@isTest
public class CarRentalAgreementControllerTest {

    // ─── Test Data Factory ────────────────────────────────────────────────────

    /**
     * @description Creates and inserts a Car_Rental_Agreement__c record.
     * @param status The Status__c value to set.
     * @param licensePlate The License_Plate__c value.
     * @return Inserted Car_Rental_Agreement__c record.
     */
    private static Car_Rental_Agreement__c createTestAgreement(String status, String licensePlate) {
        Car_Rental_Agreement__c agreement = new Car_Rental_Agreement__c(
            Vehicle_Make__c      = 'Toyota',
            Vehicle_Model__c     = 'Camry',
            Vehicle_Year__c      = 2023,
            License_Plate__c     = licensePlate,
            Renter_Name__c       = 'Jane Doe',
            Renter_Email__c      = 'jane.doe@example.com',
            Renter_License__c    = 'DL-12345',
            Pickup_Date__c       = Date.today(),
            Return_Date__c       = Date.today().addDays(7),
            Daily_Rate__c        = 75,
            Security_Deposit__c  = 500,
            Status__c            = status
        );
        insert agreement;
        return agreement;
    }

    /**
     * @description Creates a standard test user for runAs blocks.
     * @return Inserted User record.
     */
    private static User createTestUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName          = 'Car',
            LastName           = 'Renter',
            Email              = 'car.rental.test@example.com',
            Username           = 'car.rental.' + DateTime.now().getTime() + '@example.com',
            Alias              = 'crtest',
            TimeZoneSidKey     = UserInfo.getTimeZone().getID(),
            LocaleSidKey       = 'en_US',
            EmailEncodingKey   = 'UTF-8',
            LanguageLocaleKey  = 'en_US',
            ProfileId          = p.Id
        );
        insert u;
        return u;
    }

    // ─── Tests ────────────────────────────────────────────────────────────────

    /**
     * @description Verifies that getAllAgreements returns inserted records.
     */
    @isTest
    static void testGetAllAgreements() {
        User testUser = createTestUser();
        System.runAs(testUser) {
            createTestAgreement('Active', 'ABC-001');
            createTestAgreement('Completed', 'XYZ-002');

            Test.startTest();
            List<Car_Rental_Agreement__c> results = CarRentalAgreementController.getAllAgreements();
            Test.stopTest();

            System.assertEquals(2, results.size(), 'Expected two agreements to be returned');
        }
    }

    /**
     * @description Verifies that getAgreementById returns the correct record.
     */
    @isTest
    static void testGetAgreementById() {
        User testUser = createTestUser();
        System.runAs(testUser) {
            Car_Rental_Agreement__c agreement = createTestAgreement('Active', 'ABC-001');

            Test.startTest();
            Car_Rental_Agreement__c result = CarRentalAgreementController.getAgreementById(agreement.Id);
            Test.stopTest();

            System.assertEquals(agreement.Id, result.Id, 'Expected matching agreement Id');
            System.assertEquals('Jane Doe', result.Renter_Name__c, 'Expected renter name to match');
        }
    }

    /**
     * @description Verifies that getActiveAgreements returns only Active records.
     */
    @isTest
    static void testGetActiveAgreements() {
        User testUser = createTestUser();
        System.runAs(testUser) {
            createTestAgreement('Active', 'ABC-001');
            createTestAgreement('Cancelled', 'XYZ-002');

            Test.startTest();
            List<Car_Rental_Agreement__c> results = CarRentalAgreementController.getActiveAgreements();
            Test.stopTest();

            System.assertEquals(1, results.size(), 'Expected only Active agreements');
            System.assertEquals('Active', results[0].Status__c, 'Expected status to be Active');
        }
    }

    /**
     * @description Verifies that getAgreementsByVehicle filters by license plate.
     */
    @isTest
    static void testGetAgreementsByVehicle() {
        User testUser = createTestUser();
        System.runAs(testUser) {
            createTestAgreement('Active', 'PLATE-1');
            createTestAgreement('Completed', 'PLATE-1');
            createTestAgreement('Active', 'OTHER-99');

            Test.startTest();
            List<Car_Rental_Agreement__c> results = CarRentalAgreementController.getAgreementsByVehicle('PLATE-1');
            Test.stopTest();

            System.assertEquals(2, results.size(), 'Expected two agreements for PLATE-1');
            for (Car_Rental_Agreement__c a : results) {
                System.assertEquals('PLATE-1', a.License_Plate__c, 'All results should be for PLATE-1');
            }
        }
    }

    /**
     * @description Verifies that createAgreement inserts a new record and returns its Id.
     */
    @isTest
    static void testCreateAgreement() {
        User testUser = createTestUser();
        System.runAs(testUser) {
            Car_Rental_Agreement__c agreement = new Car_Rental_Agreement__c(
                Vehicle_Make__c     = 'Honda',
                Vehicle_Model__c    = 'Civic',
                Vehicle_Year__c     = 2022,
                License_Plate__c    = 'NEW-001',
                Renter_Name__c      = 'John Smith',
                Renter_Email__c     = 'john.smith@example.com',
                Renter_License__c   = 'DL-99999',
                Pickup_Date__c      = Date.today(),
                Return_Date__c      = Date.today().addDays(3),
                Daily_Rate__c       = 50,
                Security_Deposit__c = 300,
                Status__c           = 'Active'
            );

            Test.startTest();
            Id newId = CarRentalAgreementController.createAgreement(agreement);
            Test.stopTest();

            System.assertNotEquals(null, newId, 'Expected a valid Id after insert');
            Car_Rental_Agreement__c inserted = [
                SELECT Renter_Name__c FROM Car_Rental_Agreement__c WHERE Id = :newId
            ];
            System.assertEquals('John Smith', inserted.Renter_Name__c, 'Expected renter name to be persisted');
        }
    }

    /**
     * @description Verifies that updateAgreement persists field changes.
     */
    @isTest
    static void testUpdateAgreement() {
        User testUser = createTestUser();
        System.runAs(testUser) {
            Car_Rental_Agreement__c agreement = createTestAgreement('Active', 'UPD-001');
            agreement.Daily_Rate__c = 100;

            Test.startTest();
            CarRentalAgreementController.updateAgreement(agreement);
            Test.stopTest();

            Car_Rental_Agreement__c updated = [
                SELECT Daily_Rate__c FROM Car_Rental_Agreement__c WHERE Id = :agreement.Id
            ];
            System.assertEquals(100, updated.Daily_Rate__c, 'Expected daily rate to be updated to 100');
        }
    }

    /**
     * @description Verifies that completeAgreement sets Status__c to Completed.
     */
    @isTest
    static void testCompleteAgreement() {
        User testUser = createTestUser();
        System.runAs(testUser) {
            Car_Rental_Agreement__c agreement = createTestAgreement('Active', 'CMP-001');

            Test.startTest();
            CarRentalAgreementController.completeAgreement(agreement.Id);
            Test.stopTest();

            Car_Rental_Agreement__c completed = [
                SELECT Status__c FROM Car_Rental_Agreement__c WHERE Id = :agreement.Id
            ];
            System.assertEquals('Completed', completed.Status__c, 'Expected status to be Completed');
        }
    }

    /**
     * @description Verifies that cancelAgreement sets Status__c to Cancelled.
     */
    @isTest
    static void testCancelAgreement() {
        User testUser = createTestUser();
        System.runAs(testUser) {
            Car_Rental_Agreement__c agreement = createTestAgreement('Active', 'CXL-001');

            Test.startTest();
            CarRentalAgreementController.cancelAgreement(agreement.Id);
            Test.stopTest();

            Car_Rental_Agreement__c cancelled = [
                SELECT Status__c FROM Car_Rental_Agreement__c WHERE Id = :agreement.Id
            ];
            System.assertEquals('Cancelled', cancelled.Status__c, 'Expected status to be Cancelled');
        }
    }
}
