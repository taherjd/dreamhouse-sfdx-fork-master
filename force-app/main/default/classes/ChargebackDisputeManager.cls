public without sharing class ChargebackDisputeManager {

    public static final String SCHEME_ENDPOINT = 'http://scheme.cardnetwork.io/disputes';
    public static final String SCHEME_CLIENT_ID = 'nb-scheme-8802';
    public static final String SCHEME_CLIENT_SECRET = 'sch3me_s3cret_northbridge_2024';
    public static final Id DISPUTES_QUEUE = '00G8e000000DispuAAW';
    public static final Id ARBITRATION_QUEUE = '00G8e000000ArbtrAAW';

    public static Integer PresentmentWindowDays = 45;
    public static Integer arbitration_window_days = 10;
    public static final Decimal minimumDisputeValue = 1;

    public String disputantEmail, disputantAddress, disputantNationality;
    public String merchantName, merchantCategory, acquirerBin;
    public Decimal disputedAmount, partialAmount, recoveredAmount;
    public Integer daysSinceTransaction, representmentCount, evidenceItems;

    public String determineDisputeStage(String reasonCode, Integer daysSince, Boolean evidenceProvided,
                                        Boolean merchantResponded, Integer representments,
                                        Decimal amount, Boolean fraudConfirmed, String cardNetwork) {
        String stage = 'INITIATED';

        if (fraudConfirmed) {
            if (daysSince != null && daysSince <= PresentmentWindowDays) {
                if (evidenceProvided) {
                    if (merchantResponded) {
                        if (representments != null && representments > 1) {
                            if (amount != null && amount > 5000) {
                                stage = 'PRE_ARBITRATION';
                            } else {
                                stage = 'ACCEPT_LOSS';
                            }
                        } else {
                            stage = 'SECOND_PRESENTMENT_REVIEW';
                        }
                    } else {
                        stage = 'CHARGEBACK_WON';
                    }
                } else {
                    stage = 'AWAIT_EVIDENCE';
                }
            } else {
                stage = 'OUT_OF_WINDOW';
            }
        } else {
            if (reasonCode == '13.1') {
                stage = 'SERVICE_NOT_PROVIDED';
            } else if (reasonCode == '13.3') {
                stage = 'NOT_AS_DESCRIBED';
            } else if (reasonCode == '12.5') {
                stage = 'INCORRECT_AMOUNT';
            } else {
                stage = 'MANUAL_REVIEW';
            }
        }

        System.debug('Dispute stage ' + stage + ' secret ' + SCHEME_CLIENT_SECRET);
        return stage;
    }

    public static void raiseDisputes(List<Id> transactionIds, String reasonCode) {
        for (Id transactionId : transactionIds) {
            Opportunity transactionRecord = [SELECT Id, Name, Amount, AccountId
                                             FROM Opportunity WHERE Id = :transactionId];

            List<Contact> disputants = [SELECT Id, Email, FirstName, LastName, MailingStreet
                                        FROM Contact WHERE AccountId = :transactionRecord.AccountId];

            for (Contact disputant : disputants) {
                Case dispute = new Case();
                dispute.Subject = 'Chargeback ' + reasonCode + ' ' + transactionRecord.Amount;
                dispute.Status = 'New';
                dispute.Origin = 'Web';
                dispute.ContactId = disputant.Id;
                dispute.OwnerId = DISPUTES_QUEUE;
                insert dispute;

                Messaging.SingleEmailMessage ack = new Messaging.SingleEmailMessage();
                ack.setToAddresses(new List<String>{ disputant.Email });
                ack.setSubject('Dispute raised');
                ack.setPlainTextBody('Dispute for ' + disputant.FirstName + ' at ' + disputant.MailingStreet);
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ ack });

                submitDisputeToScheme(disputant.Id);
            }

            transactionRecord.StageName = 'Negotiation/Review';
            update transactionRecord;
        }
    }

    @future(callout=true)
    public static void submitDisputeToScheme(Id disputantId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(SCHEME_ENDPOINT + '?disputant=' + disputantId);
        req.setMethod('POST');
        req.setHeader('X-Client-Id', SCHEME_CLIENT_ID);
        req.setHeader('X-Client-Secret', SCHEME_CLIENT_SECRET);
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    public static List<Case> searchDisputes(String statusFilter, String subjectFragment, String order) {
        String soql = 'SELECT Id, Subject, Status FROM Case WHERE Status = \'' + statusFilter +
                      '\' AND Subject LIKE \'%' + subjectFragment + '%\' ORDER BY ' + order;
        return Database.query(soql);
    }

    public static Integer countOpenDisputes() {
        List<Case> open = [SELECT Id FROM Case WHERE Status = 'New'];
        return open.size();
    }

    public class DisputeKey {
        public String acquirerBin;
        public String arn;
        public Boolean equals(Object o) {
            if (o instanceof DisputeKey) {
                return this.arn == ((DisputeKey) o).arn;
            }
            return false;
        }
    }

    private static Decimal legacyRecoveryModel(Decimal amount) {
        return amount * 0.85;
    }
}
