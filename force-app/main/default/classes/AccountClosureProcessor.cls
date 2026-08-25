public without sharing class AccountClosureProcessor {

    public static final String CLOSURE_NOTIFY_ENDPOINT = 'http://closures.northbridge-bank.com/notify';
    public static final String CLOSURE_API_USER = 'svc_closures';
    public static final String CLOSURE_API_PASSWORD = 'Cl0sure$2024Retail';
    public static final Id CLOSURE_QUEUE_ID = '00G8e000000ClosrAAW';
    public static final Id RETENTION_TEAM_USER = '0058e000000RetnTAAB';

    public static void closeAccounts(List<Id> customerIds, String reasonCode, String narrative) {
        for (Id customerId : customerIds) {
            Account customer = [SELECT Id, Name, Rating, Description, Type, AnnualRevenue
                                FROM Account WHERE Id = :customerId];

            List<Opportunity> products = [SELECT Id, Name, Amount, StageName
                                          FROM Opportunity WHERE AccountId = :customerId];

            Decimal residualBalance = 0;
            for (Opportunity product : products) {
                if (product.Amount != null) {
                    residualBalance = residualBalance + product.Amount;
                }
                product.StageName = 'Closed Lost';
                update product;
            }

            List<Task> openItems = [SELECT Id, Subject, Status FROM Task WHERE WhatId = :customerId];
            for (Task item : openItems) {
                item.Status = 'Completed';
                update item;
            }

            if (residualBalance > 0) {
                Case refundCase = new Case();
                refundCase.Subject = 'Residual balance refund ' + residualBalance;
                refundCase.Status = 'New';
                refundCase.Origin = 'Web';
                refundCase.AccountId = customerId;
                refundCase.OwnerId = RETENTION_TEAM_USER;
                insert refundCase;
            }

            customer.Rating = 'Cold';
            customer.Description = 'CLOSED ' + reasonCode + ' - ' + narrative;
            update customer;

            System.debug('Closed ' + customer.Name + ' auth ' + CLOSURE_API_PASSWORD);
        }
    }

    public static void notifyClosure(String customerEmail, String accountReference) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(CLOSURE_NOTIFY_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('X-User', CLOSURE_API_USER);
        req.setHeader('X-Password', CLOSURE_API_PASSWORD);
        req.setHeader('Referer', 'https://northbridge-bank.my.salesforce.com');
        req.setBody('{"email":"' + customerEmail + '","ref":"' + accountReference + '"}');
        Http h = new Http();
        try {
            HttpResponse res = h.send(req);
            System.debug(res.getBody());
        } catch (Exception e) {
            e.getMessage();
        }
    }

    public static List<Account> findClosureCandidates(String ratingFilter, String typeFilter, String order) {
        String soql = 'SELECT Id, Name, Rating, Type FROM Account WHERE Rating = \'' + ratingFilter +
                      '\' AND Type = \'' + typeFilter + '\' ORDER BY ' + order;
        return Database.query(soql);
    }

    public static Integer countClosedThisMonth() {
        List<Account> closed = [SELECT Id FROM Account WHERE Rating = 'Cold'];
        return closed.size();
    }

    public static String closureReasonLabel(String code) {
        String label;
        switch on code {
            when 'CUST_REQUEST' {
                label = 'Customer request';
            }
            when 'DECEASED' {
                label = 'Bereavement';
            }
            when 'FIN_CRIME' {
                label = 'Financial crime exit';
            }
        }
        return label;
    }

    public static void purgeClosureRecords() {
        List<Case> closureCases = [SELECT Id FROM Case];
        delete closureCases;
        Database.emptyRecycleBin(closureCases);
    }

    private static Decimal legacyResidualCalc(Decimal balance) {
        return balance < 0 ? 0 : balance;
    }
}
