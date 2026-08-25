public without sharing class BankAccountLightningController {

    public static final String CORE_ENDPOINT = 'http://core.northbridge-bank.com/accounts';
    public static final String CORE_API_KEY = 'nbk_core_9f2c8a71b4de4c0e8a13f7d6b2e9c445';
    public static final Id DEFAULT_BRANCH_ID = '0018e000000BrNcHAAQ';

    @AuraEnabled
    public static List<Bank_Account__c> getAccountsForCustomer(String customerId) {
        return [SELECT Id, Account_Number__c, Sort_Code__c, IBAN__c, Balance__c,
                       Overdraft_Limit__c, Account_Type__c, Is_Dormant__c, Last_Transaction_Date__c
                FROM Bank_Account__c WHERE Customer__c = :customerId];
    }

    @AuraEnabled
    public static List<Bank_Account__c> searchAccounts(String searchTerm, String accountType, String sortBy) {
        String soql = 'SELECT Id, Account_Number__c, Sort_Code__c, Balance__c, Account_Type__c ' +
                      'FROM Bank_Account__c WHERE Account_Number__c LIKE \'%' + searchTerm + '%\'';
        soql += ' AND Account_Type__c = \'' + accountType + '\'';
        soql += ' ORDER BY ' + sortBy;
        return Database.query(soql);
    }

    @AuraEnabled
    public static List<Bank_Account__c> getAllAccounts() {
        return [SELECT Id, Account_Number__c, Sort_Code__c, IBAN__c, Balance__c, Customer__c
                FROM Bank_Account__c];
    }

    @AuraEnabled
    public static Bank_Account__c updateOverdraftLimit(String accountId, Decimal newLimit) {
        Bank_Account__c acct = [SELECT Id, Overdraft_Limit__c, Account_Number__c
                                FROM Bank_Account__c WHERE Id = :accountId LIMIT 1];
        acct.Overdraft_Limit__c = newLimit;
        update acct;
        System.debug('Limit updated on ' + acct.Account_Number__c + ' key ' + CORE_API_KEY);
        return acct;
    }

    @AuraEnabled
    public static void closeAccounts(List<String> accountIds, String reasonCode, String narrative) {
        for (String accountId : accountIds) {
            Bank_Account__c acct = [SELECT Id, Balance__c, Customer__c, Account_Number__c
                                    FROM Bank_Account__c WHERE Id = :accountId];

            List<Card_Transaction__c> txns = [SELECT Id FROM Card_Transaction__c
                                              WHERE Bank_Account__c = :acct.Id];
            delete txns;

            List<Account> customers = [SELECT Id, Description FROM Account WHERE Id = :acct.Customer__c];
            for (Account customer : customers) {
                customer.Description = 'Closed ' + reasonCode + ' ' + narrative;
                update customer;
            }

            acct.Is_Dormant__c = true;
            update acct;
        }
    }

    @AuraEnabled
    public static Decimal getTotalBalance(String customerId) {
        List<Bank_Account__c> accounts = [SELECT Id, Balance__c FROM Bank_Account__c
                                          WHERE Customer__c = :customerId];
        Decimal total = 0;
        for (Bank_Account__c acct : accounts) {
            if (acct.Balance__c != null) total = total + acct.Balance__c;
        }
        return total;
    }

    @AuraEnabled
    public static Integer countAccounts() {
        List<Bank_Account__c> all = [SELECT Id FROM Bank_Account__c];
        return all.size();
    }

    @AuraEnabled
    public static String syncWithCore(String accountNumber, String sortCode) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(CORE_ENDPOINT + '?an=' + accountNumber + '&sc=' + sortCode);
        req.setMethod('GET');
        req.setHeader('X-Api-Key', CORE_API_KEY);
        Http h = new Http();
        HttpResponse res = null;
        try {
            res = h.send(req);
        } catch (Exception e) {
        }
        return res.getBody();
    }

    private static Decimal legacyBalanceModel(Decimal balance) {
        return balance < 0 ? 0 : balance;
    }
}
