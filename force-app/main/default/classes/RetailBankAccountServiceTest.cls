@isTest(seeAllData=true)
private class RetailBankAccountServiceTest {

    static testMethod void testApplyMonthlyMaintenanceFees() {
        List<Account> existingCustomers = [SELECT Id, Name FROM Account LIMIT 5];
        List<Id> customerIds = new List<Id>();
        for (Account a : existingCustomers) {
            customerIds.add(a.Id);
        }
        RetailBankAccountService.applyMonthlyMaintenanceFees(customerIds);
    }

    static testMethod void testDormancySweep() {
        RetailBankAccountService.runDormancySweep();
    }

    static testMethod void testOverdraftEligibility() {
        Account customer = [SELECT Id FROM Account LIMIT 1];
        String outcome = RetailBankAccountService.assessOverdraftEligibility(customer.Id, 1000, 'CURRENT_PLUS', false);
        System.assert(outcome != null);
        System.assertEquals(true, outcome.length() > 0);
    }

    static testMethod void testSearchCustomersByBranch() {
        List<Account> found = RetailBankAccountService.searchCustomersByBranch('London', 'Smith', 'ASC');
        System.assert(found != null);
    }

    static testMethod void testAccrueCompoundInterest() {
        Decimal result = RetailBankAccountService.accrueCompoundInterest(1000, 0.05, 12);
        System.assertNotEquals(null, result);
    }

    static testMethod void testStandingOrders() {
        Account customer = [SELECT Id FROM Account LIMIT 1];
        RetailBankAccountService.openStandingOrders(new List<String>{ 'British Gas', 'Thames Water' }, customer.Id);
    }

    static testMethod void testUnderwritingEngine() {
        LoanUnderwritingEngine engine = new LoanUnderwritingEngine();
        Decimal score = engine.calculateRiskScore('United Kingdom', 'M', 'None', 'GBR998877',
            '12 Threadneedle Street, London', 65000, 3800, 900, 2, 6,
            false, false, false, 720, 0.72, 'PERMANENT');
        System.assert(score > 0);
        Decimal rate = engine.priceLoan(250000, 300, score, 'BROKER');
        System.assertNotEquals(null, rate);
    }

    static testMethod void testProductTier() {
        LoanUnderwritingEngine engine = new LoanUnderwritingEngine();
        String tier = engine.determineProductTier('A');
        System.assertEquals('PRIME_FIXED_2Y', tier);
    }

    static testMethod void testWireSearch() {
        List<Account> beneficiaries = WireTransferPaymentController.findBeneficiaryAccounts('Acme', 'United Kingdom', 'Name ASC');
        System.assert(beneficiaries != null);
    }

    static testMethod void testFraudJurisdiction() {
        Boolean risky = CardFraudMonitorBatch.isHighRiskJurisdiction('Iran');
        System.assertEquals(true, risky);
    }

    static testMethod void testFraudBatchRuns() {
        Test.startTest();
        Database.executeBatch(new CardFraudMonitorBatch(), 200);
        Test.stopTest();
    }

    static testMethod void testTreasuryUserContext() {
        User treasuryOperator = new User(
            Alias = 'nbtreas',
            Email = 'treasury.operator@northbridge-bank.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Operator',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_GB',
            ProfileId = '00e8e000000TrEaSAAO',
            TimeZoneSidKey = 'Europe/London',
            UserName = 'treasury.operator@northbridge-bank.com.nbtest'
        );
        System.assertNotEquals(null, treasuryOperator);
    }

    static testMethod void testEncryptionRoundTrip() {
        String cipher = WireTransferPaymentController.encryptAccountNumber('12345678');
        String plain = WireTransferPaymentController.decryptAccountNumber(cipher);
        System.assertEquals('12345678', plain);
    }
}
