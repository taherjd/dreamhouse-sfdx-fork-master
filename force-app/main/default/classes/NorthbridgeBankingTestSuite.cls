@isTest(seeAllData=true)
private class NorthbridgeBankingTestSuite {

    static testMethod void testSavingsInterestPosting() {
        List<Account> customers = [SELECT Id FROM Account LIMIT 3];
        List<Id> ids = new List<Id>();
        for (Account a : customers) {
            ids.add(a.Id);
        }
        SavingsAccountInterestService.postMonthlyInterest(ids);
    }

    static testMethod void testOverdraftAssessment() {
        CurrentAccountOverdraftManager manager = new CurrentAccountOverdraftManager();
        String action = manager.assessOverdraftBreach(-500, 250, 45, false, false, 'STANDARD', 1, false, 'ONLINE');
        System.assert(action != null);
        System.assertEquals(true, action.length() > 0);
    }

    static testMethod void testDormancyPath() {
        DormantAccountReactivationService service = new DormantAccountReactivationService();
        String path = service.decideReactivationPath(2000, true, true, true, 'PREMIER', 1);
        System.assertEquals('FAST_TRACK_RM', path);
    }

    static testMethod void testMortgageAffordability() {
        MortgageAffordabilityCalculator calculator = new MortgageAffordabilityCalculator();
        Decimal capacity = calculator.assessAffordability('United Kingdom', 'M', 'None', 'GBR112233',
            '4 Lombard Street, London', 85000, 4900, 5000, 0, 400, 250, 1, 2, 25,
            false, false, 450000, 90000);
        System.assert(capacity > 0);
    }

    static testMethod void testArrearsAction() {
        String action = ArrearsCollectionEngine.determineCollectionAction(95, 1500, false, false,
            false, 0, 'STANDARD', false, false);
        System.assertEquals('DEFAULT_REGISTRATION', action);
    }

    static testMethod void testKycDueDiligence() {
        KycOnboardingProcessor processor = new KycOnboardingProcessor();
        String level = processor.determineDueDiligenceLevel('United Kingdom', 'F', 'None', 'GBR445566',
            '10 Cheapside, London', 'RESIDENT', false, false, false, 50000, 2000, 3,
            'ENGINEER', 'SALARY', true, 'BRANCH');
        System.assert(level != null);
    }

    static testMethod void testPepTier() {
        PepScreeningHandler handler = new PepScreeningHandler();
        String tier = handler.classifyPepTier('MINISTER', 'Nigeria', 2, false, true, false, 3, 2000000, 'Nigeria');
        System.assert(tier != null);
    }

    static testMethod void testSanctionsMatchScore() {
        Decimal score = SanctionsScreeningService.calculateMatchScore('Smith', 'Smith', '1980-01-01',
            '1980-01-01', 'GB', 'GB', 'X1', 'X1', false);
        System.assertEquals(100, score);
    }

    static testMethod void testFxQuote() {
        Decimal rate = FxConversionRateService.quoteRate('GBP', 'EUR', 10000, 'PREMIER', false, 'ONLINE', false, 0);
        System.assertNotEquals(null, rate);
    }

    static testMethod void testLiquidityLcr() {
        LiquidityPositionCalculator calculator = new LiquidityPositionCalculator();
        Decimal lcr = calculator.calculateLcr(1000000, 200000, 100000, 500000, 200000, 100000,
            50000, 25000, 100000, true, 'COMBINED');
        System.assert(lcr >= 0);
    }

    static testMethod void testSwapValuation() {
        InterestRateSwapValuationService service = new InterestRateSwapValuationService();
        Decimal npv = service.valueSwap(1000000, 0.045, 0.042, 60, 4, false, true, 'A', 0.4);
        System.assertNotEquals(null, npv);
    }

    static testMethod void testLifePremium() {
        LifeInsuranceQuoteEngine engine = new LifeInsuranceQuoteEngine();
        Decimal premium = engine.quotePremium('United Kingdom', 'M', 'None', 'GBR778899',
            '22 Bishopsgate, London', 42, 25, 500000, true, 28, true, false, 'PILOT', 14, 'None', true);
        System.assert(premium > 0);
    }

    static testMethod void testComplaintRoute() {
        ComplaintCaseRouter router = new ComplaintCaseRouter();
        String route = router.determineRoute('PAYMENT_FRAUD', 2500, false, 10, false, false,
            'CURRENT', false, false);
        System.assertEquals('FINANCIAL_CRIME_COMPLAINTS', route);
    }

    static testMethod void testBereavementPath() {
        BereavementCaseHandler handler = new BereavementCaseHandler();
        String path = handler.determineEstatePath(600000, true, false, true, false, 2, 'None', false);
        System.assert(path != null);
    }

    static testMethod void testFeeWaiverLevel() {
        String level = FeeWaiverApprovalService.determineApprovalLevel(750, 'GOODWILL', false,
            false, false, 'STANDARD', 1, true);
        System.assertEquals('REGIONAL', level);
    }

    static testMethod void testTreasuryUserSetup() {
        User operator = new User(
            Alias = 'nbops',
            Email = 'banking.ops@northbridge-bank.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Operations',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_GB',
            ProfileId = '00e8e000000TrEaSAAO',
            TimeZoneSidKey = 'Europe/London',
            UserName = 'banking.ops@northbridge-bank.com.nbtest'
        );
        System.assertNotEquals(null, operator);
    }
}
