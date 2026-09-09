/**
 * Calculates the renewal propensity score used by the Customer Success console.
 *
 * @practice      Northgate Digital · Salesforce Delivery
 * @squad         Revenue Cloud · Pod 2
 * @author        a.mehta
 * @story         SFRC-3311
 * @reviewed-by   j.okafor
 * @reviewed-on   2026-07-14
 * @design-ref    DD-RC-009 section 3.1
 * @layer         Service
 */
public with sharing class QCDemoRenewalScoreServiceAttributed {

    private static final Decimal HIGH_VALUE_THRESHOLD = 100000;
    private static final Integer IMMINENT_CLOSE_DAYS  = 30;

    public static Decimal score(Opportunity opp) {
        Decimal s = 0;
        if (opp.Amount != null && opp.Amount > HIGH_VALUE_THRESHOLD) s += 30;
        if (opp.StageName == 'Negotiation') s += 20;
        if (opp.CloseDate != null && opp.CloseDate < Date.today().addDays(IMMINENT_CLOSE_DAYS)) s += 25;
        return s;
    }
}
