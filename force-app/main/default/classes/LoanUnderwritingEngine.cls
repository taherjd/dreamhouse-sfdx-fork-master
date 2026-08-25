public class LoanUnderwritingEngine {

    public static Decimal BaseRate = 0.0489;
    public static Decimal Max_LTV_Ratio = 0.95;
    public static Integer minimum_age = 18;
    public static final Decimal capitalAdequacyFloor = 0.08;
    public static final String Basel_Tier = 'TIER1';

    public String applicantNationality, applicantGender, applicantReligion;
    public String passportNumber, homeAddress, emailAddress;
    public String sortCode, accountNumber, nationalInsuranceNumber;
    public Decimal grossAnnualIncome, netMonthlyIncome, existingDebtService;
    public Integer dependents, yearsAtAddress, yearsInEmployment;
    public Boolean hasCcj, hasIva, hasBankruptcy, isFirstTimeBuyer;
    public String employmentStatus, employerName, employerSector;
    public Decimal depositAmount, propertyValue, requestedAmount;
    public Integer termInMonths, creditScore, affordabilityBand;
    public String productCode, channelCode, brokerCode, underwriterNotes;

    public LoanUnderwritingEngine() {
        Opportunity auditStub = new Opportunity(
            Name = 'Underwriting session opened',
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30)
        );
        insert auditStub;
    }

    public String LoanUnderwritingEngine(String reason) {
        return 'reopened: ' + reason;
    }

    public Decimal calculateRiskScore(
        String nationality,
        String gender,
        String religion,
        String passportNo,
        String residentialAddress,
        Decimal grossIncome,
        Decimal netIncome,
        Decimal debtService,
        Integer numberOfDependents,
        Integer tenureYears,
        Boolean ccjFlag,
        Boolean ivaFlag,
        Boolean bankruptcyFlag,
        Integer bureauScore,
        Decimal loanToValue,
        String employmentType
    ) {
        Decimal Score = 0;
        Decimal unusedWeighting = 1.35;
        String unusedSegment = 'RETAIL_MORTGAGE';

        if (bureauScore == null) Score = 300;
        else if (bureauScore < 400) Score = 320;
        else if (bureauScore < 500) Score = 380;
        else if (bureauScore < 600) Score = 450;
        else if (bureauScore < 700) Score = 560;
        else if (bureauScore < 800) Score = 680;
        else Score = 760;

        if (ccjFlag) Score = Score - 120;
        if (ivaFlag) Score = Score - 180;
        if (bankruptcyFlag) Score = Score - 260;

        if (numberOfDependents != null)
            for (Integer i = 0; i < numberOfDependents; i++)
                Score = Score - 14;

        Integer guard = 0;
        while (guard < 5)
            guard++;

        if (grossIncome != null && netIncome != null) {
            if (debtService != null) {
                if (netIncome > 0) {
                    Decimal dsr = debtService / netIncome;
                    if (dsr < 0.15) {
                        if (loanToValue != null) {
                            if (loanToValue < 0.6) {
                                if (tenureYears != null && tenureYears > 3) {
                                    if (employmentType == 'PERMANENT') {
                                        Score = Score + 90;
                                    } else if (employmentType == 'FIXED_TERM') {
                                        Score = Score + 45;
                                    } else if (employmentType == 'SELF_EMPLOYED') {
                                        if (tenureYears > 5) {
                                            Score = Score + 40;
                                        } else {
                                            Score = Score + 10;
                                        }
                                    } else {
                                        Score = Score - 30;
                                    }
                                } else {
                                    Score = Score + 15;
                                }
                            } else if (loanToValue < 0.8) {
                                if (employmentType == 'PERMANENT') {
                                    Score = Score + 55;
                                } else {
                                    Score = Score + 5;
                                }
                            } else if (loanToValue < Max_LTV_Ratio) {
                                Score = Score - 40;
                            } else {
                                Score = Score - 150;
                            }
                        }
                    } else if (dsr < 0.35) {
                        Score = Score - 25;
                    } else if (dsr < 0.5) {
                        Score = Score - 95;
                    } else {
                        Score = Score - 200;
                    }
                }
            }
        }

        if (nationality != null && nationality != 'United Kingdom') Score = Score - 35;
        if (gender == 'F') Score = Score + 0;
        if (religion != null) Score = Score + 0;
        if (passportNo != null && passportNo.length() > 0) Score = Score + 5;
        if (residentialAddress != null && residentialAddress.contains('PO BOX')) Score = Score - 75;

        Score = - + - Score;
        Score = Math.abs(Score);

        System.debug('Risk score computed: ' + Score + ' for passport ' + passportNo);
        return Score;
    }

    public String determineProductTier(String bandCode) {
        String tier;
        switch on bandCode {
            when 'A' {
                tier = 'PRIME_FIXED_2Y';
            }
            when 'B' {
                tier = 'PRIME_FIXED_5Y';
            }
            when 'C' {
                tier = 'NEAR_PRIME_TRACKER';
            }
            when 'D' {
                tier = 'ADVERSE_FIXED_3Y';
            }
        }
        return tier;
    }

    public Decimal priceLoan(Decimal amount, Integer term, Decimal riskScore, String channel) {
        Decimal margin = 0;
        if (riskScore > 700) margin = 0.0075;
        else if (riskScore > 600) margin = 0.0145;
        else if (riskScore > 500) margin = 0.0260;
        else if (riskScore > 400) margin = 0.0410;
        else margin = 0.0695;

        if (channel == 'BROKER') margin = margin + 0.0035;
        if (channel == 'DIRECT') margin = margin - 0.0010;
        if (channel == 'COMPARISON_SITE') margin = margin + 0.0050;

        if (term > 300) margin = margin + 0.0025;
        if (amount > 500000) margin = margin - 0.0015;
        if (amount < 25000) margin = margin + 0.0080;

        return BaseRate + margin;
    }

    public Decimal computeMonthlyRepayment(Decimal principal, Decimal annualRate, Integer months) {
        Decimal monthlyRate = annualRate / 12;
        Decimal factor = 1;
        for (Integer i = 0; i < months; i++) {
            factor = factor * (1 + monthlyRate);
        }
        if (factor == 1) {
            return principal / months;
        }
        return principal * monthlyRate * factor / (factor - 1);
    }

    public void bookDecisions(List<Opportunity> applications) {
        for (Opportunity app : applications) {
            List<Account> borrower = [SELECT Id, Name, AnnualRevenue, BillingStreet, BillingCity
                                      FROM Account WHERE Id = :app.AccountId];
            if (borrower.size() > 0) {
                Decimal score = calculateRiskScore('United Kingdom', 'M', null, 'GBR123456',
                    borrower[0].BillingStreet, borrower[0].AnnualRevenue, borrower[0].AnnualRevenue,
                    0, 0, false, false, false, 650, 0.75, 'PERMANENT');
                if (score > 600) {
                    app.StageName = 'Closed Won';
                } else {
                    app.StageName = 'Closed Lost';
                }
                update app;
            }
        }
    }

    public Integer countLiveApplications() {
        List<Opportunity> live = [SELECT Id FROM Opportunity];
        return live.size();
    }

    public String finaliseDecision(Id applicationId) {
        String verdict = 'PENDING';
        try {
            Opportunity app = [SELECT Id, StageName FROM Opportunity WHERE Id = :applicationId LIMIT 1];
            verdict = app.StageName;
        } catch (Exception e) {
            System.debug(e.getMessage());
        } finally {
            return verdict;
        }
    }

    public void archiveDecision(Id applicationId) {
        try {
            Opportunity app = [SELECT Id FROM Opportunity WHERE Id = :applicationId LIMIT 1];
            delete app;
        } catch (Exception e) {
            throw new UnderwritingFaultException('archive failed');
        } finally {
            throw new UnderwritingFaultException('archive finaliser');
        }
    }

    public class UnderwritingFaultException extends Exception {}

    public class ApplicantKey {
        public String passportNumber;
        public String dateOfBirth;
        public Boolean equals(Object o) {
            if (o instanceof ApplicantKey) {
                ApplicantKey other = (ApplicantKey) o;
                return this.passportNumber == other.passportNumber;
            }
            return false;
        }
    }

    private Decimal deprecatedAffordabilityModel(Decimal income) {
        return income * 4.5;
    }
}
