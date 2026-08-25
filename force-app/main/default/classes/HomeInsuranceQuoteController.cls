/**
 * @description Controller for generating and retrieving home insurance quotes.
 *              Provides methods to calculate a premium estimate and list
 *              existing home-insurance submissions for the running user.
 */
public with sharing class HomeInsuranceQuoteController {

    /** Base annual premium rate applied to the declared property value. */
    private static final Decimal BASE_RATE = 0.005;

    /** Multiplier applied when the property has a security system installed. */
    private static final Decimal SECURITY_DISCOUNT = 0.9;

    /** Maximum number of submissions returned in a single call. */
    private static final Integer MAX_RESULTS = 200;

    // -------------------------------------------------------------------------
    // Inner class
    // -------------------------------------------------------------------------

    /**
     * @description Lightweight wrapper that carries the calculated quote back
     *              to the calling LWC without exposing full SObject fields.
     */
    public class QuoteResult {
        /** @description Estimated annual premium for the home insurance policy. */
        @AuraEnabled public Decimal annualPremium { get; set; }

        /** @description Coverage amount requested by the applicant. */
        @AuraEnabled public Decimal coverageAmount { get; set; }

        /** @description Human-readable summary of the quote. */
        @AuraEnabled public String summary { get; set; }

        /**
         * @description Constructs a QuoteResult with all required fields.
         * @param annualPremium Calculated annual premium
         * @param coverageAmount Coverage amount requested
         * @param summary Human-readable quote summary
         */
        public QuoteResult(Decimal annualPremium, Decimal coverageAmount, String summary) {
            this.annualPremium = annualPremium;
            this.coverageAmount = coverageAmount;
            this.summary = summary;
        }
    }

    // -------------------------------------------------------------------------
    // AuraEnabled methods
    // -------------------------------------------------------------------------

    /**
     * @description Calculates a home insurance premium estimate.
     *              Formula: propertyValue × BASE_RATE, reduced by SECURITY_DISCOUNT
     *              when a security system is present.
     * @param propertyValue Declared market value of the property in USD
     * @param hasSecuritySystem Whether the property has a monitored security system
     * @return QuoteResult containing the estimated annual premium and a summary
     */
    @AuraEnabled(cacheable=true)
    public static QuoteResult calculateQuote(Decimal propertyValue, Boolean hasSecuritySystem) {
        if (propertyValue == null || propertyValue <= 0) {
            throw new AuraHandledException('Property value must be a positive number.');
        }

        Decimal premium = propertyValue * BASE_RATE;

        if (hasSecuritySystem == true) {
            premium = premium * SECURITY_DISCOUNT;
        }

        premium = premium.setScale(2, RoundingMode.HALF_UP);

        String summaryText = 'Estimated annual premium: $'
            + String.valueOf(premium)
            + ' for a property valued at $'
            + String.valueOf(propertyValue.setScale(2, RoundingMode.HALF_UP));

        return new QuoteResult(premium, propertyValue, summaryText);
    }

    /**
     * @description Returns home-insurance submissions for the running user,
     *              ordered by effective date ascending.
     * @return List of Submission__c records with home-insurance line of business
     */
    @AuraEnabled(cacheable=true)
    public static List<Submission__c> getHomeInsuranceSubmissions() {
        return [
            SELECT
                Id,
                Account_Name__c,
                Broker_Name__c,
                Effective_Date__c,
                Line_of_Business__c,
                Status__c,
                Submission_Number__c,
                Total_Premium__c
            FROM Submission__c
            WHERE Line_of_Business__c = 'Home'
            WITH SECURITY_ENFORCED
            ORDER BY Effective_Date__c ASC NULLS LAST
            LIMIT :MAX_RESULTS
        ];
    }
}
