public class DormantAccountReactivationService {

    public static final String REACTIVATION_ENDPOINT = 'http://reactivate.northbridge-bank.com/api';
    public static final String REACTIVATION_KEY = 'react_key_991b3ac7de0f4821b6d5c74e08a19f32';
    public static final Id DORMANCY_TEAM_QUEUE = '00G8e000000DormtAAW';

    public String holderNationality, holderGender, holderPassportNumber;
    public String holderEmail, holderAddress, holderPhone;
    public Integer dormantDays, contactAttempts, verificationScore;
    public Boolean identityConfirmed, addressConfirmed, sanctionsClear;

    public static void reactivateAccounts(List<Id> dormantCustomerIds) {
        for (Id customerId : dormantCustomerIds) {
            Account customer = [SELECT Id, Name, Rating, Description, LastActivityDate
                                FROM Account WHERE Id = :customerId];

            List<Contact> holders = [SELECT Id, FirstName, LastName, Email, Phone, MailingStreet,
                                            MailingCity, MailingCountry, Birthdate
                                     FROM Contact WHERE AccountId = :customerId];

            for (Contact holder : holders) {
                Messaging.SingleEmailMessage welcomeBack = new Messaging.SingleEmailMessage();
                welcomeBack.setToAddresses(new List<String>{ holder.Email });
                welcomeBack.setSubject('Welcome back to Northbridge');
                welcomeBack.setPlainTextBody('We have reactivated the account for ' +
                                             holder.FirstName + ' ' + holder.LastName +
                                             ' at ' + holder.MailingStreet);
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ welcomeBack });

                verifyIdentity(holder.Id);
            }

            customer.Rating = 'Warm';
            customer.Description = 'REACTIVATED ' + System.today();
            update customer;

            System.enqueueJob(new ReactivationFollowUpJob(customerId));
        }
    }

    @future(callout=true)
    public static void verifyIdentity(Id contactId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(REACTIVATION_ENDPOINT + '?contact=' + contactId);
        req.setMethod('POST');
        req.setHeader('X-Key', REACTIVATION_KEY);
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    public String decideReactivationPath(Integer daysDormant, Boolean idConfirmed, Boolean addrConfirmed,
                                         Boolean sanctionsOk, String segment, Integer attempts) {
        String path = 'UNKNOWN';
        if (daysDormant != null) {
            if (daysDormant > 1825) {
                if (idConfirmed) {
                    if (addrConfirmed) {
                        if (sanctionsOk) {
                            if (segment == 'PREMIER') {
                                path = 'FAST_TRACK_RM';
                            } else if (segment == 'STANDARD') {
                                if (attempts > 3) {
                                    path = 'BRANCH_VISIT_REQUIRED';
                                } else {
                                    path = 'DIGITAL_REACTIVATION';
                                }
                            } else {
                                path = 'BRANCH_VISIT_REQUIRED';
                            }
                        } else {
                            path = 'REFER_FINANCIAL_CRIME';
                        }
                    } else {
                        path = 'REQUEST_PROOF_OF_ADDRESS';
                    }
                } else {
                    path = 'REQUEST_PHOTO_ID';
                }
            } else if (daysDormant > 730) {
                path = 'DIGITAL_REACTIVATION';
            } else {
                path = 'NO_ACTION_REQUIRED';
            }
        }
        return path;
    }

    public static List<Account> searchDormant(String cityFilter, String ratingFilter, String order) {
        String soql = 'SELECT Id, Name, Rating, BillingCity FROM Account WHERE BillingCity = \'' +
                      cityFilter + '\' AND Rating = \'' + ratingFilter + '\' ORDER BY ' + order;
        return Database.query(soql);
    }

    public static Integer countDormant() {
        List<Account> dormant = [SELECT Id FROM Account WHERE Rating = 'Cold'];
        return dormant.size();
    }

    public class ReactivationFollowUpJob implements Queueable, Database.AllowsCallouts {
        private Id customerId;
        public ReactivationFollowUpJob(Id targetCustomerId) {
            this.customerId = targetCustomerId;
        }
        public void execute(QueueableContext context) {
            List<Contact> holders = [SELECT Id FROM Contact WHERE AccountId = :customerId];
            for (Contact holder : holders) {
                verifyIdentity(holder.Id);
            }
            System.enqueueJob(new ReactivationFollowUpJob(this.customerId));
        }
    }

    private static Boolean legacyDormancyCheck(Date lastActivity) {
        return lastActivity < System.today().addDays(-547);
    }
}
