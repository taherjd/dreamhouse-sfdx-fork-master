public class AccountManager {
    // Hardcoded credentials - Security violation
    private static String API_KEY = 'sk_live_12345abcdef67890';
    private static String PASSWORD = 'SuperSecret123!';
    
    // No sharing keyword - Security violation
    public class AccountData {
        public String accountName;
        public Decimal revenue;
        public String ssn; // PII data without encryption
    }
    
    // SOQL in loop - Performance violation
    public static void updateAccountRevenue(List<Id> accountIds) {
        for(Id accId : accountIds) {
            Account acc = [SELECT Id, AnnualRevenue FROM Account WHERE Id = :accId];
            acc.AnnualRevenue = acc.AnnualRevenue * 1.1;
            update acc; // DML in loop - Performance violation
        }
    }
    
    // No error handling - Reliability violation
    @future
    public static void callExternalAPI(String endpoint) {
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint); // No named credentials - Security violation
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + API_KEY);
        HttpResponse res = h.send(req);
        // No status code check
        String body = res.getBody();
    }
    
    // Overly complex method - Maintainability violation
    public static void processAccounts(List<Account> accounts) {
        for(Account a : accounts) {
            if(a.AnnualRevenue != null) {
                if(a.AnnualRevenue > 1000000) {
                    if(a.Industry == 'Technology') {
                        a.Rating = 'Hot';
                        if(a.NumberOfEmployees > 100) {
                            a.Type = 'Enterprise';
                            if(a.BillingCountry == 'USA') {
                                a.Priority__c = 'High';
                            } else {
                                a.Priority__c = 'Medium';
                            }
                        }
                    }
                }
            }
        }
        update accounts; // Unguarded DML
    }
    
    // Dynamic SOQL without proper escaping - Security violation
    public static List<Account> searchAccounts(String searchTerm) {
        String query = 'SELECT Id, Name FROM Account WHERE Name LIKE \'%' + searchTerm + '%\'';
        return Database.query(query); // SOQL injection risk
    }
    
    // No bulkification - Governor limit violation
    public static void createContacts(Id accountId, Integer count) {
        for(Integer i = 0; i < count; i++) {
            Contact c = new Contact();
            c.LastName = 'Contact ' + i;
            c.AccountId = accountId;
            insert c; // Single record DML in loop
        }
    }
    
    // Deprecated method usage
    @RemoteAction
    public static String oldStyleRemote() {
        return 'deprecated pattern';
    }
    
    // No test coverage comments, unused variables
    public static void messyCode() {
        Integer x = 10;
        String unused = 'never used';
        System.debug('Magic number: ' + 42); // Magic numbers
        
        // Commented out code - Code smell
        // Account a = new Account();
        // insert a;
    }
    
    // Missing null checks - Reliability violation
    public static Decimal calculateDiscount(Account acc) {
        return acc.AnnualRevenue * 0.05; // NullPointerException risk
    }
    
    // No @TestVisible, direct DML without abstraction
    private static void directDatabaseAccess() {
        delete [SELECT Id FROM Task WHERE IsClosed = true];
    }
}