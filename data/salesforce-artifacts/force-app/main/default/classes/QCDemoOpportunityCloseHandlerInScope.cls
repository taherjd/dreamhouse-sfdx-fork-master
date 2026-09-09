/**
 * Handles post close processing when an Opportunity is won.
 * Publishes a platform event for the ERP partner rather than writing to
 * finance or HR objects, which are out of scope under SOW-2026-208.
 *
 * @practice      Northgate Digital · Salesforce Delivery
 * @squad         Sales Cloud · Pod 1
 * @author        r.nakamura
 * @story         SFSC-1188
 * @reviewed-by   l.dubois
 * @scope         Sales Cloud only · SOW-2026-208
 * @scope-note    Invoice__c, Employee_Commission__c and GL_Posting__c are owned
 *                by the ERP integration partner. We publish, they consume.
 * @layer         Handler
 */
public with sharing class QCDemoOpportunityCloseHandlerInScope {

    public static void processWonOpportunities(List<Opportunity> opps) {

        List<Opportunity_Won__e> events = new List<Opportunity_Won__e>();

        for (Opportunity o : opps) {
            events.add(new Opportunity_Won__e(
                Opportunity_Id__c = o.Id,
                Amount__c         = o.Amount,
                Owner_Id__c       = o.OwnerId,
                Closed_On__c      = o.CloseDate
            ));
        }

        List<Database.SaveResult> results = EventBus.publish(events);

        for (Database.SaveResult r : results) {
            if (!r.isSuccess()) {
                System.debug(LoggingLevel.ERROR, 'Opportunity_Won__e publish failed: ' + r.getErrors());
            }
        }
    }
}
