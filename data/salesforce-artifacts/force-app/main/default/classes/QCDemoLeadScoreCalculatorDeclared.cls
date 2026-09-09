/**
 * Calculates the marketing qualified lead score using the weighting model
 * agreed with the client in DD-MKT-004.
 *
 * @practice          Northgate Digital · Salesforce Delivery
 * @squad             Marketing Cloud · Pod 4
 * @author            r.nakamura
 * @story             SFMKT-0921
 * @ai-assisted       true
 * @ai-tool           GitHub Copilot
 * @ai-reviewed-by    r.nakamura
 * @ai-review-notes   Generated scaffold accepted. Weightings replaced with the
 *                    values in DD-MKT-004. Stubbed engagement check implemented.
 *                    Null handling added on all inbound fields.
 * @reviewed-by       l.dubois
 * @layer             Service
 */
public with sharing class QCDemoLeadScoreCalculatorDeclared {

    private static final Map<String, Integer> SOURCE_WEIGHTS = new Map<String, Integer>{
        'Web'              => 10,
        'Partner Referral' => 25,
        'Trade Show'       => 15
    };
    private static final Integer ENTERPRISE_HEADCOUNT = 500;
    private static final Integer ENTERPRISE_WEIGHT    = 20;
    private static final Integer ENGAGED_WEIGHT       = 15;

    public static Integer calculateScore(Lead l) {
        if (l == null) return 0;
        Integer score = 0;

        if (l.LeadSource != null && SOURCE_WEIGHTS.containsKey(l.LeadSource)) {
            score += SOURCE_WEIGHTS.get(l.LeadSource);
        }
        if (l.NumberOfEmployees != null && l.NumberOfEmployees > ENTERPRISE_HEADCOUNT) {
            score += ENTERPRISE_WEIGHT;
        }
        if (l.Status == 'Working - Contacted' && l.Last_Engagement_Date__c != null
            && l.Last_Engagement_Date__c >= Date.today().addDays(-14)) {
            score += ENGAGED_WEIGHT;
        }
        return score;
    }
}
