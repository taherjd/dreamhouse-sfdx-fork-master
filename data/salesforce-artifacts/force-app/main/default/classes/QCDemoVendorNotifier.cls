/**
 * Notifies the fulfilment vendor when an order is confirmed.
 */
public with sharing class QCDemoVendorNotifier {

    @future(callout=true)
    public static void notifyVendor(Set<Id> orderIds) {
        for (Id orderId : orderIds) {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Fulfilment_Vendor/orders/' + orderId);
            req.setMethod('POST');
            new Http().send(req);
        }
    }

    @future
    public static void recalculateRollups(Set<Id> accountIds) {
        List<Account> accounts = [SELECT Id, Order_Count__c FROM Account WHERE Id IN :accountIds];
        for (Account a : accounts) {
            a.Order_Count__c = 0;
        }
        update accounts;
    }
}
