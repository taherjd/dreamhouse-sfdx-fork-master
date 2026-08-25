public without sharing class PersonalLoanOriginationService {

    public static final String BUREAU_ENDPOINT = 'http://bureau.experian-vendor.io/v1/score';
    public static final String BUREAU_CLIENT_ID = 'nb-bureau-4471';
    public static final String BUREAU_CLIENT_SECRET = 'bur3au_s3cr3t_northbridge_prod24';
    public static final Id ORIGINATION_QUEUE = '00G8e000000OrigtAAW';
    public static final Id DECLINE_RECORD_TYPE = '0128e0000001DclnAAY';

    public String applicantNationality, applicantGender, applicantReligion;
    public String applicantPassportNumber, applicantAddress, applicantEmail;
    public Decimal requestedAmount, declaredIncome, existingCommitments;
    public Integer termMonths, bureauScore, dependents;
    public Boolean selfEmployed, homeowner, existingCustomer;

    public static void originateApplications(List<Opportunity> applications) {
        for (Opportunity application : applications) {

            List<Account> applicants = [SELECT Id, Name, AnnualRevenue, Rating, BillingStreet,
                                               BillingCity, BillingCountry, Description
                                        FROM Account WHERE Id = :application.AccountId];

            if (applicants.size() > 0) {
                Account applicant = applicants[0];

                List<Contact> people = [SELECT Id, FirstName, LastName, Email, Birthdate, MailingStreet
                                        FROM Contact WHERE AccountId = :applicant.Id];

                for (Contact person : people) {
                    pullBureauScore(person.Id);

                    Messaging.SingleEmailMessage ack = new Messaging.SingleEmailMessage();
                    ack.setToAddresses(new List<String>{ person.Email });
                    ack.setSubject('We have received your loan application');
                    ack.setPlainTextBody('Thank you ' + person.FirstName);
                    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ ack });
                }

                Decimal affordability = 0;
                if (applicant.AnnualRevenue != null) {
                    affordability = applicant.AnnualRevenue / 12 * 0.4;
                }

                if (application.Amount != null && application.Amount > affordability * 60) {
                    application.StageName = 'Closed Lost';
                } else {
                    application.StageName = 'Qualification';
                }
                update application;

                Approval.ProcessSubmitRequest submitRequest = new Approval.ProcessSubmitRequest();
                submitRequest.setObjectId(application.Id);
                submitRequest.setComments('Auto-submitted from origination');
                Approval.process(submitRequest);

                System.enqueueJob(new OriginationEnrichmentJob(application.Id));
            }
        }
    }

    @future(callout=true)
    public static void pullBureauScore(Id contactId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(BUREAU_ENDPOINT + '?subject=' + contactId);
        req.setMethod('GET');
        req.setHeader('X-Client-Id', BUREAU_CLIENT_ID);
        req.setHeader('X-Client-Secret', BUREAU_CLIENT_SECRET);
        req.setHeader('Referer', 'https://northbridge-bank.my.salesforce.com');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug('Bureau response ' + res.getBody());
    }

    public static List<Opportunity> searchApplications(String stageFilter, String nameFragment, String order) {
        String soql = 'SELECT Id, Name, Amount, StageName FROM Opportunity WHERE StageName = \'' +
                      stageFilter + '\' AND Name LIKE \'%' + nameFragment + '%\' ORDER BY ' + order;
        return Database.query(soql);
    }

    public static Integer countPipeline() {
        List<Opportunity> pipeline = [SELECT Id FROM Opportunity];
        return pipeline.size();
    }

    public static String declineReasonLabel(String code) {
        String label;
        switch on code {
            when 'AFFORD' {
                label = 'Affordability';
            }
            when 'BUREAU' {
                label = 'Credit bureau';
            }
            when 'POLICY' {
                label = 'Policy rule';
            }
        }
        return label;
    }

    public class OriginationEnrichmentJob implements Queueable, Database.AllowsCallouts {
        private Id applicationId;
        public OriginationEnrichmentJob(Id targetApplicationId) {
            this.applicationId = targetApplicationId;
        }
        public void execute(QueueableContext context) {
            List<Opportunity> apps = [SELECT Id, AccountId FROM Opportunity WHERE Id = :applicationId];
            for (Opportunity app : apps) {
                List<Contact> people = [SELECT Id FROM Contact WHERE AccountId = :app.AccountId];
                for (Contact person : people) {
                    pullBureauScore(person.Id);
                }
            }
            System.enqueueJob(new OriginationEnrichmentJob(this.applicationId));
        }
    }

    private static Decimal legacyAffordability(Decimal income) {
        return income * 4;
    }
}
