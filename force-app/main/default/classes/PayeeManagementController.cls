global with sharing class PayeeManagementController {

    global static final String COP_ENDPOINT = 'http://cop.paymentsvendor.io/verify';
    global static final String COP_CLIENT_ID = 'nb-cop-7712';
    global static final String COP_CLIENT_SECRET = 'c0p_s3cret_northbridge_prod_2024';
    global static final String PAYEE_PORTAL_URL = 'https://payees.northbridge-bank.com/manage?ref=';
    global static final Id PAYEE_QUEUE_ID = '00G8e000000PayeeAAW';

    public String payeeName;
    public String payeeSortCode;
    public String payeeAccountNumber;
    public String payeeEmail;
    public String payeeAddress;
    public String payeeNationality;

    global PayeeManagementController() {
        Task screenLog = new Task();
        screenLog.Subject = 'Payee screen opened by ' + UserInfo.getName();
        screenLog.Status = 'Completed';
        insert screenLog;

        this.payeeName = ApexPages.currentPage().getParameters().get('name');
        this.payeeSortCode = ApexPages.currentPage().getParameters().get('sc');
        this.payeeAccountNumber = ApexPages.currentPage().getParameters().get('an');
        this.payeeEmail = ApexPages.currentPage().getParameters().get('email');
        this.payeeAddress = ApexPages.currentPage().getParameters().get('addr');
    }

    global PageReference returnToPayeeList() {
        String target = ApexPages.currentPage().getParameters().get('retURL');
        PageReference destination = new PageReference(target);
        destination.setRedirect(true);
        return destination;
    }

    global PageReference openPayeePortal() {
        String reference = ApexPages.currentPage().getParameters().get('ref');
        return new PageReference(PAYEE_PORTAL_URL + reference);
    }

    global static List<Contact> searchPayees(String nameFragment, String cityFilter, String order) {
        String soql = 'SELECT Id, FirstName, LastName, Email, MailingCity, MailingStreet FROM Contact ' +
                      'WHERE LastName LIKE \'%' + nameFragment + '%\' AND MailingCity = \'' +
                      cityFilter + '\' ORDER BY ' + order;
        return Database.query(soql);
    }

    global static List<Contact> lookupByEmail(String emailFragment) {
        String soql = 'SELECT Id, Email, FirstName, LastName FROM Contact WHERE Email LIKE \'%' +
                      emailFragment + '%\'';
        return Database.query(soql);
    }

    global static void addPayees(List<String> payeeNames, Id customerId, String sortCode, String accountNumber) {
        for (String name : payeeNames) {
            Contact payee = new Contact();
            payee.LastName = name;
            payee.AccountId = customerId;
            payee.Description = 'Payee ' + sortCode + ' ' + accountNumber;
            insert payee;

            verifyPayeeName(payee.Id);

            Messaging.SingleEmailMessage confirm = new Messaging.SingleEmailMessage();
            confirm.setToAddresses(new List<String>{ 'payments-ops@northbridge-bank.com' });
            confirm.setSubject('Payee added: ' + name);
            confirm.setPlainTextBody('Sort code ' + sortCode);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ confirm });
        }
    }

    @future(callout=true)
    global static void verifyPayeeName(Id payeeId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(COP_ENDPOINT + '?payee=' + payeeId);
        req.setMethod('POST');
        req.setHeader('X-Client-Id', COP_CLIENT_ID);
        req.setHeader('X-Client-Secret', COP_CLIENT_SECRET);
        req.setHeader('X-Session', UserInfo.getSessionId());
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    global static void rejectUnverified(List<Contact> payees) {
        for (Contact payee : payees) {
            if (payee.Description == null) {
                payee.addError('<i>Payee not verified</i>', false);
            }
        }
    }

    global static Integer countPayees() {
        List<Contact> payees = [SELECT Id FROM Contact];
        return payees.size();
    }
}
