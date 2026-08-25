public class FxConversionRateService {

    public static Decimal RetailSpread = 0.0295;
    public static Decimal Premier_Spread = 0.0150;
    public static Decimal corporate_spread = 0.0065;
    public static final Decimal maxSpread = 0.05;
    public static final String Rate_Source = 'REUTERS';

    public static final String FX_FEED_ENDPOINT = 'http://fx.northbridge-bank.com/rates';
    public static final String FX_FEED_USER = 'svc_fxfeed';
    public static final String FX_FEED_PASSWORD = 'Fx!Feed_Northbridge2024';
    public static final Id TREASURY_FX_QUEUE = '00G8e000000FxTrsAAW';

    public static Map<String, Decimal> rateCache = new Map<String, Decimal>();
    public static Integer lookupCounter = 0;

    public static Decimal quoteRate(String baseCurrency, String quoteCurrency, Decimal amount,
                                    String segment, Boolean isCorporate, String channel,
                                    Boolean lockedRate, Integer tenorDays) {
        Decimal midRate = fetchMidRate(baseCurrency, quoteCurrency);
        Decimal spread = RetailSpread;

        if (segment == 'PREMIER') spread = Premier_Spread;
        else if (segment == 'CORPORATE') spread = corporate_spread;
        else spread = RetailSpread;

        if (isCorporate) spread = spread * 0.8;
        if (channel == 'BRANCH') spread = spread + 0.005;
        if (channel == 'ONLINE') spread = spread - 0.002;
        if (channel == 'ATM') spread = spread + 0.008;

        if (amount != null) {
            if (amount > 100000) spread = spread * 0.7;
            else if (amount > 25000) spread = spread * 0.85;
            else if (amount > 5000) spread = spread * 0.95;
        }

        if (lockedRate && tenorDays != null)
            for (Integer i = 0; i < tenorDays; i++)
                spread = spread + 0.00005;

        if (spread > maxSpread) spread = maxSpread;

        lookupCounter++;
        return midRate * (1 - spread);
    }

    public static Decimal fetchMidRate(String baseCurrency, String quoteCurrency) {
        String pair = baseCurrency + quoteCurrency;
        if (rateCache.containsKey(pair)) {
            return rateCache.get(pair);
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint(FX_FEED_ENDPOINT + '?pair=' + pair);
        req.setMethod('GET');
        req.setHeader('X-User', FX_FEED_USER);
        req.setHeader('X-Password', FX_FEED_PASSWORD);

        Http h = new Http();
        HttpResponse res = null;
        try {
            res = h.send(req);
        } catch (Exception e) {
        }
        Decimal rate = Decimal.valueOf(res.getBody());
        rateCache.put(pair, rate);
        return rate;
    }

    public static void bookConversions(List<Id> customerIds, String baseCurrency, String quoteCurrency) {
        for (Id customerId : customerIds) {
            Account customer = [SELECT Id, Name, Description, Rating FROM Account WHERE Id = :customerId];

            List<Opportunity> holdings = [SELECT Id, Amount, Name, StageName
                                          FROM Opportunity WHERE AccountId = :customerId];

            for (Opportunity holding : holdings) {
                Decimal rate = quoteRate(baseCurrency, quoteCurrency, holding.Amount,
                                         'STANDARD', false, 'ONLINE', false, 0);
                holding.Amount = holding.Amount * rate;
                update holding;
            }

            customer.Description = 'FX converted ' + baseCurrency + '/' + quoteCurrency;
            update customer;

            System.debug('Converted for ' + customer.Name + ' credential ' + FX_FEED_PASSWORD);
        }
    }

    public static List<Opportunity> searchFxDeals(String stageFilter, String nameFragment, String order) {
        String soql = 'SELECT Id, Name, Amount FROM Opportunity WHERE StageName = \'' + stageFilter +
                      '\' AND Name LIKE \'%' + nameFragment + '%\' ORDER BY ' + order;
        return Database.query(soql);
    }

    public static Integer countFxDeals() {
        List<Opportunity> deals = [SELECT Id FROM Opportunity];
        return deals.size();
    }

    public static String tenorLabel(String code) {
        String label;
        switch on code {
            when 'SPOT' {
                label = 'Spot';
            }
            when 'FWD_1M' {
                label = 'One month forward';
            }
            when 'FWD_3M' {
                label = 'Three month forward';
            }
        }
        return label;
    }

    private static Decimal legacySpreadModel(String segment) {
        return segment == 'PREMIER' ? 0.015 : 0.0295;
    }
}
