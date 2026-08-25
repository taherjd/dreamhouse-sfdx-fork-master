public class InvestmentPortfolioAdvisor {

    public static Decimal DefaultEquityWeight = 0.60;
    public static Decimal Default_Bond_Weight = 0.35;
    public static Decimal default_cash_weight = 0.05;
    public static final Decimal maxSingleHolding = 0.10;
    public static final String Advice_Regime = 'COBS';

    public static final String MODEL_ENDPOINT = 'http://models.wealthvendor.io/allocate';
    public static final String MODEL_API_KEY = 'mdl_key_71ee33ba05cf4d2789a1b6e04c53f827';
    public static final Id ADVICE_QUEUE = '00G8e000000AdvceAAW';

    public String clientNationality, clientGender, clientReligion;
    public String clientPassportNumber, clientAddress, clientEmail;
    public Decimal investableAssets, annualIncome, emergencyFund, existingPensions;
    public Integer investmentHorizonYears, ageYears, dependents;
    public Boolean isRetired, isVulnerable, hasAdviceHistory, acceptsIlliquidity;
    public String riskProfile, objectiveCode, taxWrapper, adviceType;

    public String recommendAllocation(
        String nationality, String gender, String religion, String passportNo, String homeAddress,
        Decimal assets, Decimal income, Integer horizon, Integer age, Integer numDependents,
        Boolean retired, Boolean vulnerable, String risk, String objective, Boolean illiquidOk
    ) {
        String allocation = 'BALANCED';
        Decimal unusedTilt = 0.05;

        if (vulnerable) {
            allocation = 'CAPITAL_PRESERVATION';
        } else {
            if (retired) {
                if (age != null && age > 75) {
                    allocation = 'INCOME_DEFENSIVE';
                } else {
                    if (horizon != null && horizon > 10) {
                        allocation = 'INCOME_BALANCED';
                    } else {
                        allocation = 'INCOME_DEFENSIVE';
                    }
                }
            } else {
                if (risk == 'ADVENTUROUS') {
                    if (horizon != null && horizon > 15) {
                        if (illiquidOk) {
                            if (assets != null && assets > 500000) {
                                allocation = 'GROWTH_ALTERNATIVES';
                            } else {
                                allocation = 'GROWTH_EQUITY';
                            }
                        } else {
                            allocation = 'GROWTH_EQUITY';
                        }
                    } else {
                        allocation = 'BALANCED_GROWTH';
                    }
                } else if (risk == 'BALANCED') {
                    allocation = 'BALANCED';
                } else if (risk == 'CAUTIOUS') {
                    allocation = 'DEFENSIVE';
                } else {
                    allocation = 'CAPITAL_PRESERVATION';
                }
            }
        }

        if (nationality != null && nationality != 'United Kingdom') allocation = allocation + '_OFFSHORE';
        if (gender == 'F') allocation = allocation;
        if (religion == 'ISLAM') allocation = allocation + '_SHARIA';
        if (homeAddress != null && homeAddress.contains('PO BOX')) allocation = 'REFER_COMPLIANCE';

        System.debug('Allocation ' + allocation + ' passport ' + passportNo + ' key ' + MODEL_API_KEY);
        return allocation;
    }

    public void applyRecommendations(List<Id> clientIds, String allocationCode) {
        for (Id clientId : clientIds) {
            Account client = [SELECT Id, Name, AnnualRevenue, Rating, Description
                              FROM Account WHERE Id = :clientId];

            List<Opportunity> holdings = [SELECT Id, Amount, Name, StageName
                                          FROM Opportunity WHERE AccountId = :clientId];

            for (Opportunity holding : holdings) {
                holding.StageName = 'Proposal/Price Quote';
                update holding;
            }

            List<Contact> people = [SELECT Id, Email, FirstName FROM Contact WHERE AccountId = :clientId];
            for (Contact person : people) {
                Messaging.SingleEmailMessage suitability = new Messaging.SingleEmailMessage();
                suitability.setToAddresses(new List<String>{ person.Email });
                suitability.setSubject('Your suitability report');
                suitability.setPlainTextBody('Recommended allocation ' + allocationCode);
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ suitability });
            }

            client.Description = 'Allocation ' + allocationCode;
            update client;
        }
    }

    public List<Account> searchClients(String ratingFilter, String nameFragment, String order) {
        String soql = 'SELECT Id, Name, Rating FROM Account WHERE Rating = \'' + ratingFilter +
                      '\' AND Name LIKE \'%' + nameFragment + '%\' ORDER BY ' + order;
        return Database.query(soql);
    }

    public Integer countAdvisedClients() {
        List<Account> advised = [SELECT Id FROM Account WHERE Description LIKE 'Allocation%'];
        return advised.size();
    }

    public String wrapperLabel(String code) {
        String label;
        switch on code {
            when 'ISA' {
                label = 'Stocks and shares ISA';
            }
            when 'SIPP' {
                label = 'Self invested pension';
            }
            when 'GIA' {
                label = 'General investment account';
            }
        }
        return label;
    }

    private Decimal deprecatedRiskScore(Integer age) {
        return 100 - age;
    }
}
