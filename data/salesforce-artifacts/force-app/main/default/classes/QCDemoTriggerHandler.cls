/**
 * Practice trigger framework base class. Every object trigger extends this and
 * overrides only the contexts it needs. Provides recursion control and a single
 * place to add bypass logic for data loads.
 *
 * @practice   Northgate Digital · Salesforce Delivery
 * @layer      Framework
 * @author     j.okafor
 * @story      SFCORE-0102
 */
public abstract class QCDemoTriggerHandler {

    private static Set<String> bypassed = new Set<String>();

    public void run() {
        if (isBypassed()) return;

        if (Trigger.isBefore && Trigger.isInsert) beforeInsert(Trigger.new);
        if (Trigger.isBefore && Trigger.isUpdate) beforeUpdate(Trigger.new, Trigger.oldMap);
        if (Trigger.isAfter  && Trigger.isInsert) afterInsert(Trigger.new);
        if (Trigger.isAfter  && Trigger.isUpdate) afterUpdate(Trigger.new, Trigger.oldMap);
    }

    protected virtual void beforeInsert(List<SObject> records) {}
    protected virtual void beforeUpdate(List<SObject> records, Map<Id, SObject> oldMap) {}
    protected virtual void afterInsert(List<SObject> records) {}
    protected virtual void afterUpdate(List<SObject> records, Map<Id, SObject> oldMap) {}

    public static void bypass(String handlerName) { bypassed.add(handlerName); }
    public static void clearBypass(String handlerName) { bypassed.remove(handlerName); }
    private Boolean isBypassed() { return bypassed.contains(String.valueOf(this).split(':')[0]); }
}
