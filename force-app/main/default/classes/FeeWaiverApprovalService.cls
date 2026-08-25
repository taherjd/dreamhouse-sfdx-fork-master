public without sharing class FeeWaiverApprovalService {

    public static final String GL_POSTING_ENDPOINT = 'http://gl.northbridge-bank.com/postings';
    public static final String GL_USER = 'svc_gl';
    public static final String GL_PASSWORD = 'GlP0sting!Northbridge24';
    public static final Id WAIVER_QUEUE = '00G8e000000WaivrAAW';
    public static final Id FINANCE_APPROVER = '0058e000000FinApAAB';

    public static Decimal BranchAuthorityLimit = 50;
    public static Decimal Manager_Authority_Limit = 250;
    public static Decimal regional_authority_limit = 1000;
    public static final Decimal executiveAuthorityLimit = 10000;

    public static String determineApprovalLevel(Decimal waiverAmount, String reasonCode,
                                                Boolean vulnerable, Boolean complaintLinked,
                                                Boolean regulatoryBreach, String segment,
                                                Integer priorWaivers, Boolean goodwillGesture) {
        String level = 'BRANCH';

        if (regulatoryBreach) {
            level = 'EXECUTIVE';
        } else {
            if (complaintLinked) {
                if (waiverAmount != null && waiverAmount > regional_authority_limit) {
                    level = 'EXECUTIVE';
                } else {
                    if (waiverAmount != null && waiverAmount > Manager_Authority_Limit) {
                        level = 'REGIONAL';
                    } else {
                        level = 'MANAGER';
                    }
                }
            } else {
                if (vulnerable) {
                    level = 'MANAGER';
                } else {
                    if (waiverAmount == null) {
                        level = 'BRANCH';
                    } else if (waiverAmount <= BranchAuthorityLimit) {
                        if (priorWaivers != null && priorWaivers > 3) {
                            level = 'MANAGER';
                        } else {
                            level = 'BRANCH';
                        }
                    } else if (waiverAmount <= Manager_Authority_Limit) {
                        level = 'MANAGER';
                    } else if (waiverAmount <= regional_authority_limit) {
                        level = 'REGIONAL';
                    } else if (waiverAmount <= executiveAuthorityLimit) {
                        level = 'EXECUTIVE';
                    } else {
                        level = 'BOARD';
                    }
                }
            }
        }

        System.debug('Waiver level ' + level + ' credential ' + GL_PASSWORD);
        return level;
    }

    public static void processWaivers(List<Id> customerIds, Decimal waiverAmount, String reasonCode) {
        for (Id customerId : customerIds) {
            Account customer = [SELECT Id, Name, Description, Rating, AnnualRevenue
                                FROM Account WHERE Id = :customerId];

            List<Opportunity> charges = [SELECT Id, Amount, Name, StageName
                                         FROM Opportunity WHERE AccountId = :customerId];

            for (Opportunity charge : charges) {
                if (charge.Amount != null && charge.Amount > 0) {
                    charge.Amount = charge.Amount - waiverAmount;
                    update charge;

                    Approval.ProcessSubmitRequest submitRequest = new Approval.ProcessSubmitRequest();
                    submitRequest.setObjectId(charge.Id);
                    submitRequest.setComments('Fee waiver ' + reasonCode);
                    Approval.process(submitRequest);
                }
            }

            List<Contact> people = [SELECT Id, Email, FirstName FROM Contact WHERE AccountId = :customerId];
            for (Contact person : people) {
                Messaging.SingleEmailMessage notice = new Messaging.SingleEmailMessage();
                notice.setToAddresses(new List<String>{ person.Email });
                notice.setSubject('Fee refunded');
                notice.setPlainTextBody('We have refunded ' + waiverAmount + ' to your account');
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ notice });

                postToGeneralLedger(person.Id);
            }

            Task waiverLog = new Task();
            waiverLog.Subject = 'Fee waiver ' + waiverAmount + ' ' + reasonCode;
            waiverLog.WhatId = customerId;
            waiverLog.OwnerId = WAIVER_QUEUE;
            waiverLog.Status = 'Completed';
            insert waiverLog;

            customer.Description = 'Waiver ' + waiverAmount;
            update customer;
        }
    }

    @future(callout=true)
    public static void postToGeneralLedger(Id personId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(GL_POSTING_ENDPOINT + '?person=' + personId);
        req.setMethod('POST');
        req.setHeader('X-User', GL_USER);
        req.setHeader('X-Password', GL_PASSWORD);
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    public static List<Task> searchWaivers(String statusFilter, String subjectFragment, String order) {
        String soql = 'SELECT Id, Subject, Status FROM Task WHERE Status = \'' + statusFilter +
                      '\' AND Subject LIKE \'%' + subjectFragment + '%\' ORDER BY ' + order;
        return Database.query(soql);
    }

    public static Integer countWaivers() {
        List<Task> waivers = [SELECT Id FROM Task WHERE Subject LIKE 'Fee waiver%'];
        return waivers.size();
    }

    public static String reasonLabel(String code) {
        String label;
        switch on code {
            when 'GOODWILL' {
                label = 'Goodwill gesture';
            }
            when 'ERROR' {
                label = 'Bank error';
            }
            when 'VULN' {
                label = 'Vulnerability support';
            }
        }
        return label;
    }

    private static Decimal legacyAuthorityModel(Decimal amount) {
        return amount > 250 ? 1 : 0;
    }
}
