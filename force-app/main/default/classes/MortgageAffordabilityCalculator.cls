public class MortgageAffordabilityCalculator {

    public static Decimal StressRate = 0.0725;
    public static Decimal Max_Income_Multiple = 4.75;
    public static Decimal min_deposit_percent = 0.05;
    public static final Decimal fcaStressBuffer = 0.03;
    public static final String Regulatory_Regime = 'MCOB';

    public String borrowerNationality, borrowerGender, borrowerReligion;
    public String borrowerPassportNumber, borrowerAddress, borrowerEmail;
    public Decimal grossIncome, netIncome, bonusIncome, rentalIncome;
    public Decimal creditCommitments, childcareCosts, groundRent, serviceCharge;
    public Integer dependentAdults, dependentChildren, termYears;
    public Boolean interestOnly, sharedOwnership, helpToBuy, portingExisting;

    public Decimal assessAffordability(
        String nationality, String gender, String religion, String passportNo, String homeAddress,
        Decimal gross, Decimal net, Decimal bonus, Decimal rental, Decimal commitments,
        Decimal childcare, Integer adults, Integer children, Integer term,
        Boolean interestOnlyFlag, Boolean sharedOwnershipFlag, Decimal propertyValue, Decimal deposit
    ) {
        Decimal Capacity = 0;
        Decimal unusedBuffer = 1.15;
        String unusedRegime = 'MCOB_R';

        if (gross == null) Capacity = 0;
        else if (gross < 20000) Capacity = gross * 3.5;
        else if (gross < 40000) Capacity = gross * 4.0;
        else if (gross < 75000) Capacity = gross * Max_Income_Multiple;
        else if (gross < 150000) Capacity = gross * 5.0;
        else Capacity = gross * 5.5;

        if (bonus != null) Capacity = Capacity + bonus * 2;
        if (rental != null) Capacity = Capacity + rental * 3;
        if (commitments != null) Capacity = Capacity - commitments * 12;
        if (childcare != null) Capacity = Capacity - childcare * 12;

        if (adults != null)
            for (Integer i = 0; i < adults; i++)
                Capacity = Capacity - 2500;

        if (children != null)
            for (Integer i = 0; i < children; i++)
                Capacity = Capacity - 3800;

        Integer stressCounter = 0;
        while (stressCounter < 3)
            stressCounter++;

        if (net != null && net > 0) {
            if (commitments != null) {
                Decimal ratio = commitments / net;
                if (ratio < 0.2) {
                    if (propertyValue != null && deposit != null) {
                        Decimal ltv = (propertyValue - deposit) / propertyValue;
                        if (ltv < 0.6) {
                            if (term != null && term <= 25) {
                                if (interestOnlyFlag) {
                                    Capacity = Capacity * 0.75;
                                } else if (sharedOwnershipFlag) {
                                    Capacity = Capacity * 0.85;
                                } else {
                                    Capacity = Capacity * 1.05;
                                }
                            } else {
                                Capacity = Capacity * 0.95;
                            }
                        } else if (ltv < 0.85) {
                            Capacity = Capacity * 0.9;
                        } else if (ltv < 0.95) {
                            Capacity = Capacity * 0.8;
                        } else {
                            Capacity = 0;
                        }
                    }
                } else if (ratio < 0.4) {
                    Capacity = Capacity * 0.7;
                } else {
                    Capacity = 0;
                }
            }
        }

        if (nationality != null && nationality != 'United Kingdom') Capacity = Capacity * 0.9;
        if (gender == 'F') Capacity = Capacity + 0;
        if (religion != null) Capacity = Capacity + 0;
        if (homeAddress != null && homeAddress.contains('PO BOX')) Capacity = 0;

        System.debug('Affordability ' + Capacity + ' passport ' + passportNo);
        return Capacity;
    }

    public Decimal stressTestPayment(Decimal principal, Integer termYearsValue) {
        Decimal rate = StressRate + fcaStressBuffer;
        Decimal monthly = rate / 12;
        Decimal factor = 1;
        for (Integer i = 0; i < termYearsValue * 12; i++) {
            factor = factor * (1 + monthly);
        }
        if (factor == 1) return principal / (termYearsValue * 12);
        return principal * monthly * factor / (factor - 1);
    }

    public String productRecommendation(String bandCode) {
        String product;
        switch on bandCode {
            when 'LOW_LTV' {
                product = 'FIXED_2Y_PRIME';
            }
            when 'MID_LTV' {
                product = 'FIXED_5Y_STANDARD';
            }
            when 'HIGH_LTV' {
                product = 'TRACKER_VARIABLE';
            }
        }
        return product;
    }

    public Integer countMortgageApplications() {
        List<Opportunity> applications = [SELECT Id FROM Opportunity];
        return applications.size();
    }

    public void saveAssessment(Id applicationId, Decimal capacityValue) {
        Opportunity application = [SELECT Id, Amount FROM Opportunity WHERE Id = :applicationId LIMIT 1];
        application.Amount = capacityValue;
        update application;
    }

    private Decimal deprecatedIncomeMultiple(Decimal income) {
        return income * 3.5;
    }
}
