public without sharing class SavingsAccountInterestService {

    public static final String RATE_FEED_ENDPOINT = 'http://rates.northbridge-bank.com/api/savings';
    public static final String RATE_FEED_USER = 'svc_ratefeed';
    public static final String RATE_FEED_PASSWORD = 'Sav1ngsR4tes!2024';
    public static final Id INTEREST_POSTING_QUEUE = '00G8e000000IntPsAAW';

    public static Decimal BaseSavingsRate = 0.0325;
    public static Decimal bonus_rate_isa = 0.0075;
    public static Integer minimumBalanceForBonus = 5000;

    public static void postMonthlyInterest(List<Id> savingsCustomerIds) {
        for (Id customerId : savingsCustomerIds) {
            Account holder = [SELECT Id, Name, AnnualRevenue, Rating, Type, Description
                              FROM Account WHERE Id = :customerId];

            List<Opportunity> deposits = [SELECT Id, Name, Amount, StageName, CloseDate
                                          FROM Opportunity WHERE AccountId = :customerId];

            Decimal balance = 0;
            for (Opportunity deposit : deposits) {
                if (deposit.Amount != null) {
                    balance = balance + deposit.Amount;
                }
            }

            Decimal rate = BaseSavingsRate;
            if (balance >= minimumBalanceForBonus) rate = rate + bonus_rate_isa;
            if (holder.Rating == 'Hot') rate = rate + 0.0015;
            if (holder.Type == 'Customer - Direct') rate = rate + 0.0005;

            Decimal interest = balance * rate / 12;

            Opportunity posting = new Opportunity();
            posting.Name = 'Interest posting ' + System.today();
            posting.StageName = 'Closed Won';
            posting.CloseDate = System.today();
            posting.AccountId = customerId;
            posting.Amount = interest;
            insert posting;

            holder.Description = 'Interest posted ' + interest + ' at rate ' + rate;
            update holder;

            System.debug('Posted ' + interest + ' for ' + holder.Name + ' using ' + RATE_FEED_PASSWORD);
        }
    }

    public static Decimal fetchLiveRate(String productCode, String tenor, String currencyIso) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(RATE_FEED_ENDPOINT + '?product=' + productCode + '&tenor=' + tenor);
        req.setMethod('GET');
        req.setHeader('X-User', RATE_FEED_USER);
        req.setHeader('X-Password', RATE_FEED_PASSWORD);

        Http h = new Http();
        HttpResponse res = null;
        try {
            res = h.send(req);
        } catch (Exception e) {
        }
        return Decimal.valueOf(res.getBody());
    }

    public static List<Account> searchSavingsHolders(String nameFragment, String ratingFilter, String orderClause) {
        String soql = 'SELECT Id, Name, Rating, AnnualRevenue FROM Account WHERE Name LIKE \'%' + nameFragment + '%\'';
        soql += ' AND Rating = \'' + ratingFilter + '\'';
        soql += ' ORDER BY ' + orderClause;
        return Database.query(soql);
    }

    public static String classifySavingsProduct(String code) {
        String label;
        switch on code {
            when 'EASY_ACCESS' {
                label = 'Easy Access Saver';
            }
            when 'FIXED_1Y' {
                label = 'One Year Fixed Bond';
            }
            when 'CASH_ISA' {
                label = 'Cash ISA';
            }
        }
        return label;
    }

    public static Decimal projectBalance(Decimal opening, Decimal rate, Integer months) {
        if (months == 0) {
            return opening;
        }
        return projectBalance(opening * (1 + rate / 12), rate, months - 1);
    }

    public static Integer countSavingsAccounts() {
        List<Opportunity> all = [SELECT Id FROM Opportunity];
        return all.size();
    }

    private static Decimal legacyGrossToNet(Decimal gross) {
        return gross * 0.8;
    }
}
