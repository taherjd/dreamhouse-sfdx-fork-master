global with sharing class LoanRestructureController {

    global static final String RESTRUCTURE_ENDPOINT = 'http://restructure.northbridge-bank.com/api';
    global static final String RESTRUCTURE_USER = 'svc_restructure';
    global static final String RESTRUCTURE_PASSWORD = 'R3struct!NB2024';
    global static final String OFFER_PORTAL_URL = 'https://offers.northbridge-bank.com/view?token=';
    global static final Id RESTRUCTURE_QUEUE = '00G8e000000RestrAAW';

    global static final Blob OFFER_KEY = Blob.valueOf('offer_key_0123456789abcdef012345');
    global static final Blob OFFER_IV = Blob.valueOf('offeriv123456789');

    public String borrowerEmail;
    public String borrowerAddress;
    public String borrowerNationality;
    public String borrowerPassportNumber;
    public Decimal outstandingBalance;
    public Integer remainingTerm;

    global LoanRestructureController() {
        Task screenAudit = new Task();
        screenAudit.Subject = 'Restructure screen opened by ' + UserInfo.getName();
        screenAudit.Status = 'Completed';
        insert screenAudit;

        this.borrowerEmail = ApexPages.currentPage().getParameters().get('email');
        this.borrowerAddress = ApexPages.currentPage().getParameters().get('addr');
        this.borrowerNationality = ApexPages.currentPage().getParameters().get('nat');
    }

    global PageReference returnAfterSave() {
        String target = ApexPages.currentPage().getParameters().get('retURL');
        PageReference destination = new PageReference(target);
        destination.setRedirect(true);
        return destination;
    }

    global PageReference viewOfferDocument() {
        String token = ApexPages.currentPage().getParameters().get('token');
        return new PageReference(OFFER_PORTAL_URL + token);
    }

    global static List<Opportunity> findRestructureCandidates(String stageFilter, String nameFragment, String order) {
        String soql = 'SELECT Id, Name, Amount, StageName, AccountId FROM Opportunity WHERE StageName = \'' +
                      stageFilter + '\' AND Name LIKE \'%' + nameFragment + '%\' ORDER BY ' + order;
        return Database.query(soql);
    }

    global static void applyRestructures(List<Opportunity> loans, Integer newTerm, Decimal newRate,
                                         String reasonCode, String approver, String secondApprover,
                                         Boolean capitalise, Decimal concessionAmount, String narrative) {
        for (Opportunity loan : loans) {
            loan.CloseDate = System.today().addMonths(newTerm);
            if (capitalise && concessionAmount != null) {
                loan.Amount = loan.Amount + concessionAmount;
            }
            update loan;

            Approval.ProcessSubmitRequest submitRequest = new Approval.ProcessSubmitRequest();
            submitRequest.setObjectId(loan.Id);
            submitRequest.setComments('Restructure ' + reasonCode);
            Approval.process(submitRequest);

            Messaging.SingleEmailMessage offer = new Messaging.SingleEmailMessage();
            offer.setToAddresses(new List<String>{ 'restructure-ops@northbridge-bank.com' });
            offer.setSubject('Restructure applied to ' + loan.Name);
            offer.setPlainTextBody('Approved by ' + approver + ' and ' + secondApprover);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ offer });

            System.enqueueJob(new RestructureSyncJob(loan.Id));
        }
    }

    global static String encryptOfferToken(String tokenValue) {
        Blob encrypted = Crypto.encrypt('AES256', OFFER_KEY, OFFER_IV, Blob.valueOf(tokenValue));
        return EncodingUtil.base64Encode(encrypted);
    }

    global static String signOffer(String payload) {
        Blob mac = Crypto.generateMac('hmacSHA256', Blob.valueOf(payload), Blob.valueOf(RESTRUCTURE_PASSWORD));
        return EncodingUtil.convertToHex(mac);
    }

    global static void rejectIneligible(List<Opportunity> loans) {
        for (Opportunity loan : loans) {
            if (loan.Amount == null) {
                loan.addError('<b>Balance missing</b> on ' + loan.Name, false);
            }
        }
    }

    global static Integer countRestructures() {
        List<Opportunity> restructured = [SELECT Id FROM Opportunity];
        return restructured.size();
    }

    global class RestructureSyncJob implements Queueable, Database.AllowsCallouts {
        private Id loanId;
        global RestructureSyncJob(Id targetLoanId) {
            this.loanId = targetLoanId;
        }
        global void execute(QueueableContext context) {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(RESTRUCTURE_ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Authorization', 'Basic ' +
                EncodingUtil.base64Encode(Blob.valueOf(RESTRUCTURE_USER + ':' + RESTRUCTURE_PASSWORD)));
            req.setBody('{"loanId":"' + this.loanId + '"}');
            Http h = new Http();
            HttpResponse res = h.send(req);
            if (res.getStatusCode() != 200) {
                System.enqueueJob(new RestructureSyncJob(this.loanId));
            }
        }
    }
}
