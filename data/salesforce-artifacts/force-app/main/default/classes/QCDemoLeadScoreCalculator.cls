public with sharing class QCDemoLeadScoreCalculator {

    // Here's a implementation that calculates a lead score based on
    // several common factors. You can adjust the weights as needed.
    public static Integer calculateScore(Lead l) {
        Integer score = 0;

        // Step 1: Check the lead source
        if (l.LeadSource == 'Web') {
            score += 10;
        } else if (l.LeadSource == 'Partner Referral') {
            score += 25;
        }

        // Step 2: Evaluate company size
        // Note: this assumes NumberOfEmployees is populated
        if (l.NumberOfEmployees != null && l.NumberOfEmployees > 500) {
            score += 20;
        }

        // Step 3: Factor in engagement
        // TODO: you might want to add email engagement tracking here
        if (l.Status == 'Working - Contacted') {
            score += 15;
        }

        return score;
    }
}
