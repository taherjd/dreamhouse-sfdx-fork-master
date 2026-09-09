/**
 * Handler for the Contract object. All Contract automation lives here.
 *
 * @practice      Northgate Digital · Salesforce Delivery
 * @squad         Revenue Cloud · Pod 2
 * @author        a.mehta
 * @story         SFRC-3340
 * @reviewed-by   j.okafor
 * @layer         Handler
 */
public with sharing class QCDemoContractTriggerHandler extends QCDemoTriggerHandler {

    private static final Integer DEFAULT_TERM_MONTHS = 12;
    private static final Decimal EXEC_APPROVAL_THRESHOLD = 250000;

    protected override void beforeInsert(List<SObject> records) {
        QCDemoContractService.applyDefaults((List<Contract>) records, DEFAULT_TERM_MONTHS);
    }

    protected override void afterUpdate(List<SObject> records, Map<Id, SObject> oldMap) {
        QCDemoContractService.raiseApprovalTasks(
            (List<Contract>) records,
            (Map<Id, Contract>) oldMap,
            EXEC_APPROVAL_THRESHOLD
        );
    }
}
