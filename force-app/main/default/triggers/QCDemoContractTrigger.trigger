/**
 * @practice   Northgate Digital · Salesforce Delivery
 * @pattern    One trigger per object, no logic in the trigger body.
 *             All handling delegated to the practice trigger framework.
 * @story      SFRC-3340
 */
trigger QCDemoContractTrigger on Contract (before insert, before update, after insert, after update) {
    new QCDemoContractTriggerHandler().run();
}
