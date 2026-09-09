public with sharing class QCDemoRenewalScoreService {

    public static Decimal score(Opportunity opp) {
        Decimal s = 0;
        if (opp.Amount != null && opp.Amount > 100000) s += 30;
        if (opp.StageName == 'Negotiation') s += 20;
        if (opp.CloseDate < Date.today().addDays(30)) s += 25;
        return s;
    }
}
