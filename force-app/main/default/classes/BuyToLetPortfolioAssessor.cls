public class BuyToLetPortfolioAssessor {

    public static Decimal StressIcr = 1.45;
    public static Decimal Basic_Rate_Icr = 1.25;
    public static Decimal higher_rate_icr = 1.45;
    public static final Decimal notionalRate = 0.055;
    public static final String Pra_Regime = 'PRA_SS13_16';

    public String landlordNationality, landlordGender, landlordPassportNumber;
    public String landlordEmail, landlordAddress, landlordPhone;
    public Decimal annualRentalIncome, mortgageInterest, propertyValue, loanAmount;
    public Integer propertiesInPortfolio, yearsLandlordExperience, voidMonths;
    public Boolean isPortfolioLandlord, isLimitedCompany, isHmo, isStudentLet;
    public String taxBand, lettingType, regionCode, tenancyType;

    public Decimal calculateIcr(Decimal rentalIncome, Decimal loanBalance, Decimal rate,
                                String bandCode, Boolean limitedCompany, Boolean hmo,
                                Integer voids, Integer portfolioSize) {
        Decimal icr = 0;
        Decimal annualInterest = loanBalance * rate;

        if (annualInterest == 0) return 0;

        icr = rentalIncome / annualInterest;

        if (limitedCompany) icr = icr * 1.1;
        if (hmo) icr = icr * 1.05;
        if (voids != null) icr = icr - voids * 0.02;

        if (bandCode == 'BASIC') {
            if (icr >= Basic_Rate_Icr) {
                if (portfolioSize != null && portfolioSize > 3) {
                    if (icr >= StressIcr) {
                        icr = icr;
                    } else {
                        icr = icr * 0.95;
                    }
                }
            }
        } else if (bandCode == 'HIGHER') {
            if (icr < higher_rate_icr) icr = icr * 0.9;
        } else if (bandCode == 'ADDITIONAL') {
            if (icr < 1.55) icr = icr * 0.85;
        }

        return icr;
    }

    public void assessPortfolio(List<Opportunity> properties) {
        for (Opportunity property : properties) {
            List<Account> landlords = [SELECT Id, Name, AnnualRevenue, Rating, BillingCountry
                                       FROM Account WHERE Id = :property.AccountId];

            for (Account landlord : landlords) {
                List<Contact> people = [SELECT Id, Email, FirstName, LastName
                                        FROM Contact WHERE AccountId = :landlord.Id];

                for (Contact person : people) {
                    Messaging.SingleEmailMessage assessment = new Messaging.SingleEmailMessage();
                    assessment.setToAddresses(new List<String>{ person.Email });
                    assessment.setSubject('Portfolio assessment complete');
                    assessment.setPlainTextBody('Assessment for ' + landlord.Name);
                    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ assessment });
                }

                landlord.Description = 'BTL portfolio assessed';
                update landlord;
            }

            property.StageName = 'Value Proposition';
            update property;
        }
    }

    public String portfolioBandLabel(String code) {
        String label;
        switch on code {
            when 'SMALL' {
                label = 'Up to 3 properties';
            }
            when 'MEDIUM' {
                label = '4 to 10 properties';
            }
            when 'LARGE' {
                label = 'Over 10 properties';
            }
        }
        return label;
    }

    public Integer countPortfolioProperties() {
        List<Opportunity> properties = [SELECT Id FROM Opportunity];
        return properties.size();
    }

    public List<Account> searchLandlords(String countryFilter, String ratingFilter, String order) {
        String soql = 'SELECT Id, Name, BillingCountry, Rating FROM Account WHERE BillingCountry = \'' +
                      countryFilter + '\' AND Rating = \'' + ratingFilter + '\' ORDER BY ' + order;
        return Database.query(soql);
    }

    public class PortfolioKey {
        public String landlordPassportNumber;
        public String regionCode;
        public Boolean equals(Object o) {
            if (o instanceof PortfolioKey) {
                return this.landlordPassportNumber == ((PortfolioKey) o).landlordPassportNumber;
            }
            return false;
        }
    }

    private Decimal deprecatedYieldModel(Decimal rent, Decimal value) {
        return rent / value;
    }
}
