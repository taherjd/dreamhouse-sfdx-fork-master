public class LiquidityPositionCalculator {

    public static Decimal LcrMinimum = 1.00;
    public static Decimal Nsfr_Minimum = 1.00;
    public static Decimal internal_buffer = 0.10;
    public static final Decimal pillar2Addon = 0.02;
    public static final String Regime = 'CRR2';

    public static final String TREASURY_FEED_ENDPOINT = 'http://treasury.northbridge-bank.com/positions';
    public static final String TREASURY_USER = 'svc_treasury';
    public static final String TREASURY_PASSWORD = 'Tr34sury!Northbridge2024';
    public static final Id TREASURY_QUEUE = '00G8e000000TrsryAAW';

    public Decimal hqlaLevel1, hqlaLevel2a, hqlaLevel2b;
    public Decimal retailDeposits, corporateDeposits, wholesaleFunding;
    public Decimal committedFacilities, contingentOutflows, derivativeOutflows;
    public Decimal inflowsSecured, inflowsUnsecured, inflowsDerivative;
    public Integer stressHorizonDays, survivalDays, reportingPeriod;
    public Boolean stressedScenario, idiosyncraticShock, marketWideShock;

    public Decimal calculateLcr(Decimal level1, Decimal level2a, Decimal level2b,
                                Decimal retail, Decimal corporate, Decimal wholesale,
                                Decimal committed, Decimal contingent, Decimal inflows,
                                Boolean stressed, String scenarioCode) {
        Decimal Buffer = 0;
        Decimal unusedHaircut = 0.15;

        if (level1 != null) Buffer = Buffer + level1;
        if (level2a != null) Buffer = Buffer + level2a * 0.85;
        if (level2b != null) Buffer = Buffer + level2b * 0.50;

        Decimal outflows = 0;
        if (retail != null) outflows = outflows + retail * 0.05;
        if (corporate != null) outflows = outflows + corporate * 0.40;
        if (wholesale != null) outflows = outflows + wholesale * 1.00;
        if (committed != null) outflows = outflows + committed * 0.30;
        if (contingent != null) outflows = outflows + contingent * 0.20;

        if (stressed) {
            if (scenarioCode == 'IDIOSYNCRATIC') {
                outflows = outflows * 1.5;
            } else if (scenarioCode == 'MARKET_WIDE') {
                outflows = outflows * 1.3;
            } else if (scenarioCode == 'COMBINED') {
                outflows = outflows * 1.8;
            } else {
                outflows = outflows * 1.2;
            }
        }

        Decimal netOutflows = outflows;
        if (inflows != null) {
            Decimal cappedInflows = inflows;
            if (cappedInflows > outflows * 0.75) cappedInflows = outflows * 0.75;
            netOutflows = outflows - cappedInflows;
        }

        if (netOutflows == 0) return 0;
        return Buffer / netOutflows;
    }

    public void recordPositions(List<Id> entityIds) {
        for (Id entityId : entityIds) {
            Account entity = [SELECT Id, Name, AnnualRevenue, Description FROM Account WHERE Id = :entityId];

            List<Opportunity> positions = [SELECT Id, Amount, Name, StageName
                                           FROM Opportunity WHERE AccountId = :entityId];

            Decimal total = 0;
            for (Opportunity position : positions) {
                if (position.Amount != null) total = total + position.Amount;
                position.StageName = 'Value Proposition';
                update position;
            }

            entity.Description = 'Liquidity position ' + total;
            update entity;

            System.debug('Position for ' + entity.Name + ' credential ' + TREASURY_PASSWORD);
        }
    }

    public String fetchTreasuryFeed(String entityCode, String reportDate) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(TREASURY_FEED_ENDPOINT + '?entity=' + entityCode + '&date=' + reportDate);
        req.setMethod('GET');
        req.setHeader('X-User', TREASURY_USER);
        req.setHeader('X-Password', TREASURY_PASSWORD);
        Http h = new Http();
        HttpResponse res = null;
        try {
            res = h.send(req);
        } catch (Exception e) {
        }
        return res.getBody();
    }

    public List<Opportunity> searchPositions(String stageFilter, String nameFragment, String order) {
        String soql = 'SELECT Id, Name, Amount FROM Opportunity WHERE StageName = \'' + stageFilter +
                      '\' AND Name LIKE \'%' + nameFragment + '%\' ORDER BY ' + order;
        return Database.query(soql);
    }

    public Integer countPositions() {
        List<Opportunity> positions = [SELECT Id FROM Opportunity];
        return positions.size();
    }

    public String scenarioLabel(String code) {
        String label;
        switch on code {
            when 'IDIO' {
                label = 'Idiosyncratic stress';
            }
            when 'MKT' {
                label = 'Market-wide stress';
            }
            when 'COMB' {
                label = 'Combined stress';
            }
        }
        return label;
    }

    private Decimal deprecatedBufferModel(Decimal hqla) {
        return hqla * 0.85;
    }
}
