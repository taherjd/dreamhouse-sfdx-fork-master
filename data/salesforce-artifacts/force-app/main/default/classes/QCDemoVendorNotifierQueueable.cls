/**
 * Notifies the fulfilment vendor when an order is confirmed.
 * Implemented as a Queueable per the practice async standard: Queueable gives
 * us chaining, a job Id we can log against the record, typed state and a
 * finalizer for retry handling. None of that is possible with @future.
 *
 * @practice      Northgate Digital · Salesforce Delivery
 * @squad         Service Cloud · Pod 5
 * @author        a.mehta
 * @story         SFSVC-2044
 * @reviewed-by   j.okafor
 * @pattern       Async · Queueable with Finalizer, never @future
 * @layer         Service
 */
public with sharing class QCDemoVendorNotifierQueueable
        implements Queueable, Database.AllowsCallouts, Finalizer {

    private final List<Id> orderIds;
    private final Integer attempt;

    public QCDemoVendorNotifierQueueable(List<Id> orderIds) {
        this(orderIds, 1);
    }

    private QCDemoVendorNotifierQueueable(List<Id> orderIds, Integer attempt) {
        this.orderIds = orderIds;
        this.attempt  = attempt;
    }

    public void execute(QueueableContext ctx) {
        System.attachFinalizer(this);

        for (Id orderId : orderIds) {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Fulfilment_Vendor/orders/' + orderId);
            req.setMethod('POST');
            req.setTimeout(30000);

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() >= 400) {
                throw new CalloutException('Vendor notification failed: ' + res.getStatusCode());
            }
        }
    }

    public void execute(FinalizerContext ctx) {
        if (ctx.getResult() == ParentJobResult.UNHANDLED_EXCEPTION && attempt < 3) {
            System.enqueueJob(new QCDemoVendorNotifierQueueable(orderIds, attempt + 1));
        }
    }
}
