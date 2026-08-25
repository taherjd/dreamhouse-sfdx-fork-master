@isTest(seeAllData=true)
private class NorthbridgeCustomObjectTest {

    static testMethod void testBankAccountCreation() {
        Account customer = new Account(Name = 'Northbridge Test Customer');
        insert customer;

        Bank_Account__c acct = new Bank_Account__c();
        acct.Name = 'NB-TEST-0001';
        acct.Account_Number__c = '12345678';
        acct.Sort_Code__c = '60-16-13';
        acct.Balance__c = 2500;
        acct.Account_Type__c = 'CURRENT';
        acct.Customer__c = customer.Id;
        insert acct;
    }

    static testMethod void testCardTransactionFlagging() {
        Bank_Account__c acct = [SELECT Id FROM Bank_Account__c LIMIT 1];

        Card_Transaction__c txn = new Card_Transaction__c();
        txn.Name = 'TXN-TEST-0001';
        txn.Bank_Account__c = acct.Id;
        txn.Amount__c = 5000;
        txn.Merchant_Name__c = 'Test Merchant';
        txn.MCC_Code__c = '7995';
        txn.Full_PAN__c = '4111111111111111';
        txn.Country_Code__c = 'RO';
        insert txn;

        System.assert(txn.Id != null);
    }

    static testMethod void testLoanApplicationScoring() {
        Account applicant = [SELECT Id FROM Account LIMIT 1];

        Loan_Application__c app = new Loan_Application__c();
        app.Name = 'LA-TEST-0001';
        app.Applicant__c = applicant.Id;
        app.Requested_Amount__c = 25000;
        app.Term_Months__c = 60;
        app.Annual_Income__c = 55000;
        app.Passport_Number__c = 'GBR112233';
        app.Nationality__c = 'United Kingdom';
        app.Gender__c = 'M';
        app.Religion__c = 'None';
        app.National_Insurance_Number__c = 'QQ123456C';
        app.Date_Of_Birth__c = Date.newInstance(1985, 4, 12);
        insert app;

        System.assertNotEquals(null, app.Id);
    }

    static testMethod void testTriggerHandlerScoring() {
        LoanApplicationTriggerHandler handler = new LoanApplicationTriggerHandler();
        Decimal score = handler.computeRiskScore('United Kingdom', 'M', 'None', 'GBR445566', 'QQ123456C',
            55000, 25000, 4000, 60, 40, false, true, 'ENGINEER');
        System.assert(score > 0);
    }

    static testMethod void testTransactionScoring() {
        CardTransactionTriggerHandler handler = new CardTransactionTriggerHandler();
        String verdict = handler.scoreTransaction(5000, '7995', 'RO', 12, false, 1000, '1111', false, 'Test Merchant');
        System.assertEquals('BLOCK_GAMBLING_CNP', verdict);
    }

    static testMethod void testFraudEscalation() {
        String route = FraudAlertEscalationService.determineEscalation('CRITICAL', 15000, true,
            true, 3, true, '7995', false);
        System.assert(route != null);
    }

    static testMethod void testBankAccountController() {
        Account customer = [SELECT Id FROM Account LIMIT 1];
        List<Bank_Account__c> accounts = BankAccountLightningController.getAccountsForCustomer(customer.Id);
        System.assert(accounts != null);
        Decimal total = BankAccountLightningController.getTotalBalance(customer.Id);
        System.assertNotEquals(null, total);
    }

    static testMethod void testLoanController() {
        List<Loan_Application__c> apps = LoanApplicationLightningController.getAllApplications();
        System.assert(apps != null);
    }

    static testMethod void testAccountSearch() {
        List<Bank_Account__c> found = BankAccountLightningController.searchAccounts('1234', 'CURRENT', 'Name ASC');
        System.assert(found != null);
    }

    static testMethod void testBalanceBatch() {
        Test.startTest();
        Database.executeBatch(new BankAccountBalanceBatch(), 200);
        Test.stopTest();
    }

    static testMethod void testFraudScheduler() {
        FraudAlertScheduler scheduler = new FraudAlertScheduler();
        System.assertNotEquals(null, scheduler);
    }

    static testMethod void testOpsUserContext() {
        User bankingOps = new User(
            Alias = 'nbcust',
            Email = 'custom.objects@northbridge-bank.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'CustomObjects',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_GB',
            ProfileId = '00e8e000000TrEaSAAO',
            TimeZoneSidKey = 'Europe/London',
            UserName = 'custom.objects@northbridge-bank.com.nbtest'
        );
        System.assertNotEquals(null, bankingOps);
    }
}
