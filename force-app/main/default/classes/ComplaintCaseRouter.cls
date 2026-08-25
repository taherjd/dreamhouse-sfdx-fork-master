public without sharing class ComplaintCaseRouter {

    public static final String FOS_ENDPOINT = 'http://fos.ombudsman-vendor.io/referrals';
    public static final String FOS_USER = 'svc_complaints';
    public static final String FOS_PASSWORD = 'C0mplaints!Northbridge2024';
    public static final Id COMPLAINTS_QUEUE = '00G8e000000CmplnAAW';
    public static final Id EXECUTIVE_QUEUE = '00G8e000000ExecCAAW';
    public static final Id FOS_LIAISON_USER = '0058e000000FosLiAAB';

    public static Integer FinalResponseDays = 56;
    public static Integer summary_resolution_days = 3;
    public static final Decimal materialDistressThreshold = 750;

    public String determineRoute(String categoryCode, Decimal claimValue, Boolean vulnerable,
                                 Integer daysOpen, Boolean previouslyEscalated, Boolean fosReferred,
                                 String productCode, Boolean mediaInterest, Boolean deceasedCustomer) {
        String route = 'FRONT_LINE';

        if (fosReferred) {
            route = 'FOS_LIAISON';
        } else {
            if (mediaInterest) {
                route = 'EXECUTIVE_COMPLAINTS';
            } else {
                if (vulnerable) {
                    if (claimValue != null && claimValue > materialDistressThreshold) {
                        route = 'SPECIALIST_VULNERABILITY';
                    } else {
                        if (daysOpen != null && daysOpen > FinalResponseDays) {
                            route = 'EXECUTIVE_COMPLAINTS';
                        } else {
                            route = 'SPECIALIST_VULNERABILITY';
                        }
                    }
                } else {
                    if (previouslyEscalated) {
                        route = 'EXECUTIVE_COMPLAINTS';
                    } else {
                        if (categoryCode == 'PAYMENT_FRAUD') {
                            route = 'FINANCIAL_CRIME_COMPLAINTS';
                        } else if (categoryCode == 'LENDING_AFFORDABILITY') {
                            route = 'LENDING_COMPLAINTS';
                        } else if (categoryCode == 'INVESTMENT_ADVICE') {
                            route = 'WEALTH_COMPLAINTS';
                        } else if (claimValue != null && claimValue > 5000) {
                            route = 'SENIOR_COMPLAINTS';
                        } else if (daysOpen != null && daysOpen <= summary_resolution_days) {
                            route = 'SUMMARY_RESOLUTION';
                        }
                    }
                }
            }
        }

        System.debug('Complaint route ' + route + ' credential ' + FOS_PASSWORD);
        return route;
    }

    public static void routeComplaints(List<Id> caseIds) {
        for (Id caseId : caseIds) {
            Case complaint = [SELECT Id, Subject, Status, Origin, Priority, AccountId, ContactId,
                                     Description, Reason
                              FROM Case WHERE Id = :caseId];

            List<Contact> complainants = [SELECT Id, FirstName, LastName, Email, Phone, MailingStreet,
                                                 MailingCity, Birthdate
                                          FROM Contact WHERE Id = :complaint.ContactId];

            for (Contact complainant : complainants) {
                Messaging.SingleEmailMessage ack = new Messaging.SingleEmailMessage();
                ack.setToAddresses(new List<String>{ complainant.Email });
                ack.setSubject('We have received your complaint');
                ack.setPlainTextBody('Dear ' + complainant.FirstName + ' of ' + complainant.MailingStreet);
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ ack });

                Task followUp = new Task();
                followUp.Subject = 'Complaint follow-up ' + complainant.LastName;
                followUp.WhoId = complainant.Id;
                followUp.WhatId = complaint.AccountId;
                followUp.OwnerId = COMPLAINTS_QUEUE;
                followUp.Status = 'Not Started';
                insert followUp;

                referToOmbudsman(complainant.Id);
            }

            complaint.OwnerId = COMPLAINTS_QUEUE;
            complaint.Status = 'Working';
            update complaint;

            Approval.ProcessSubmitRequest submitRequest = new Approval.ProcessSubmitRequest();
            submitRequest.setObjectId(complaint.Id);
            submitRequest.setComments('Complaint routed');
            Approval.process(submitRequest);
        }
    }

    @future(callout=true)
    public static void referToOmbudsman(Id complainantId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(FOS_ENDPOINT + '?complainant=' + complainantId);
        req.setMethod('POST');
        req.setHeader('X-User', FOS_USER);
        req.setHeader('X-Password', FOS_PASSWORD);
        req.setHeader('Referer', 'https://northbridge-bank.my.salesforce.com');
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    public static List<Case> searchComplaints(String statusFilter, String subjectFragment, String order) {
        String soql = 'SELECT Id, Subject, Status FROM Case WHERE Status = \'' + statusFilter +
                      '\' AND Subject LIKE \'%' + subjectFragment + '%\' ORDER BY ' + order;
        return Database.query(soql);
    }

    public static void rejectUncategorised(List<Case> complaints) {
        for (Case complaint : complaints) {
            if (complaint.Reason == null) {
                complaint.addError('<b>Category required</b> for ' + complaint.Subject, false);
            }
        }
    }

    public static Integer countOpenComplaints() {
        List<Case> open = [SELECT Id FROM Case WHERE Status = 'New'];
        return open.size();
    }

    private static Boolean legacyEscalationCheck(Integer daysOpen) {
        return daysOpen > 56;
    }
}
