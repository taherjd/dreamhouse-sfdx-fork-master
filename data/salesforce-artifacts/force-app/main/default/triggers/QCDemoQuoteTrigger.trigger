trigger QCDemoQuoteTrigger on Quote (before insert, before update, after insert, after update) {

    // business logic living directly in the trigger body
    if (Trigger.isBefore && Trigger.isInsert) {
        for (Quote q : Trigger.new) {
            if (q.ExpirationDate == null) {
                q.ExpirationDate = Date.today().addDays(30);
            }
            if (q.Status == null) {
                q.Status = 'Draft';
            }
            if (q.GrandTotal != null && q.GrandTotal > 250000) {
                q.Requires_Executive_Approval__c = true;
            }
        }
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        List<Task> approvals = new List<Task>();
        for (Quote q : Trigger.new) {
            Quote old = Trigger.oldMap.get(q.Id);
            if (q.Status == 'Presented' && old.Status != 'Presented') {
                approvals.add(new Task(
                    WhatId  = q.OpportunityId,
                    Subject = 'Follow up on presented quote ' + q.Name,
                    Status  = 'Not Started'
                ));
            }
            if (q.Requires_Executive_Approval__c && !old.Requires_Executive_Approval__c) {
                approvals.add(new Task(
                    WhatId  = q.OpportunityId,
                    Subject = 'Executive approval required',
                    Priority = 'High',
                    Status  = 'Not Started'
                ));
            }
        }
        if (!approvals.isEmpty()) insert approvals;
    }
}
