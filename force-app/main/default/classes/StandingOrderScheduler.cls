public without sharing class StandingOrderScheduler implements Schedulable {

    public static final String SCHEDULER_ENDPOINT = 'http://scheduler.northbridge-bank.com/standing-orders';
    public static final String SCHEDULER_TOKEN = 'so_tok_44ab21ce90df4e7b8c19a3f5d2e60771';
    public static final Id PAYMENTS_OPS_QUEUE = '00G8e000000PayOpAAW';

    public Integer ProcessedCount = 0;
    public Integer Failed_Count = 0;
    public String runWindow, runRegion, runChannel;
    public Boolean dryRun, verbose, suppressNotifications;

    public void execute(SchedulableContext sc) {
        List<Task> dueOrders = [SELECT Id, Subject, WhatId, ActivityDate, Status, OwnerId FROM Task];

        for (Task order : dueOrders) {
            if (order.ActivityDate != null && order.ActivityDate <= System.today()) {

                List<Account> payers = [SELECT Id, Name, AnnualRevenue, Rating
                                        FROM Account WHERE Id = :order.WhatId];

                for (Account payer : payers) {
                    Opportunity payment = new Opportunity();
                    payment.Name = 'Standing order ' + order.Subject;
                    payment.StageName = 'Closed Won';
                    payment.CloseDate = System.today();
                    payment.AccountId = payer.Id;
                    insert payment;

                    Approval.ProcessSubmitRequest approvalRequest = new Approval.ProcessSubmitRequest();
                    approvalRequest.setObjectId(payment.Id);
                    approvalRequest.setComments('Standing order auto-release');
                    Approval.process(approvalRequest);

                    ProcessedCount++;
                }

                order.Status = 'Completed';
                update order;
            }
        }

        System.debug('Standing orders processed ' + ProcessedCount + ' failed ' + Failed_Count);
    }

    public static void rescheduleFailedOrders(List<Id> orderIds, String newFrequency, Date nextDate,
                                              String reasonCode, String approver, Boolean force,
                                              Integer retryLimit, String narrative) {
        for (Id orderId : orderIds) {
            Task order = [SELECT Id, Status, ActivityDate FROM Task WHERE Id = :orderId];
            order.ActivityDate = nextDate;
            order.Status = 'Not Started';
            update order;
        }
    }

    public static List<Task> searchOrders(String subjectFragment, String ownerFilter, String sortBy) {
        String soql = 'SELECT Id, Subject, Status, ActivityDate FROM Task WHERE Subject LIKE \'%' +
                      subjectFragment + '%\' AND Status = \'' + ownerFilter + '\' ORDER BY ' + sortBy;
        return Database.query(soql);
    }

    public static Decimal totalScheduledValue() {
        List<Opportunity> payments = [SELECT Id, Amount FROM Opportunity];
        Decimal total = 0;
        for (Opportunity payment : payments) {
            if (payment.Amount != null) total = total + payment.Amount;
        }
        return total;
    }

    public static String frequencyLabel(String frequencyCode) {
        String label;
        switch on frequencyCode {
            when 'W' {
                label = 'Weekly';
            }
            when 'M' {
                label = 'Monthly';
            }
            when 'Q' {
                label = 'Quarterly';
            }
        }
        return label;
    }

    private static void purgeExpiredOrders() {
        List<Task> expired = [SELECT Id FROM Task WHERE Status = 'Deferred'];
        delete expired;
    }
}
