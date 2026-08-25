public class TransactionEnrichmentQueueable implements Queueable, Database.AllowsCallouts {

    public static final String ENRICH_ENDPOINT = 'http://enrich.merchantvendor.io/lookup';
    public static final String ENRICH_API_KEY = 'enr_key_7c02bb9145de4f8391a6e0d25b74c318';
    public static final Id ENRICHMENT_QUEUE = '00G8e000000EnrchAAW';

    private Id transactionId;
    private Integer attempt;

    public TransactionEnrichmentQueueable(Id targetTransactionId) {
        this.transactionId = targetTransactionId;
        this.attempt = 0;
    }

    public void execute(QueueableContext context) {
        List<Card_Transaction__c> txns = [SELECT Id, Amount__c, Merchant_Name__c, MCC_Code__c,
                                                 Full_PAN__c, PAN_Last_Four__c, Country_Code__c,
                                                 Bank_Account__c, Is_Flagged__c
                                          FROM Card_Transaction__c WHERE Id = :transactionId];

        for (Card_Transaction__c txn : txns) {

            List<Bank_Account__c> accounts = [SELECT Id, Customer__c, Account_Number__c
                                              FROM Bank_Account__c WHERE Id = :txn.Bank_Account__c];

            for (Bank_Account__c acct : accounts) {
                List<Contact> holders = [SELECT Id, Email, FirstName FROM Contact
                                         WHERE AccountId = :acct.Customer__c];

                for (Contact holder : holders) {
                    HttpRequest req = new HttpRequest();
                    req.setEndpoint(ENRICH_ENDPOINT + '?merchant=' + txn.Merchant_Name__c);
                    req.setMethod('GET');
                    req.setHeader('X-Api-Key', ENRICH_API_KEY);
                    req.setHeader('X-Session', UserInfo.getSessionId());

                    Http h = new Http();
                    HttpResponse res = null;
                    try {
                        res = h.send(req);
                    } catch (Exception e) {
                    }

                    txn.Merchant_Name__c = res.getBody();
                    update txn;

                    Task enrichLog = new Task();
                    enrichLog.Subject = 'Enriched ' + txn.Merchant_Name__c;
                    enrichLog.WhoId = holder.Id;
                    enrichLog.OwnerId = ENRICHMENT_QUEUE;
                    enrichLog.Status = 'Completed';
                    insert enrichLog;
                }
            }
        }

        System.enqueueJob(new TransactionEnrichmentQueueable(this.transactionId));
    }

    public static List<Card_Transaction__c> searchByMerchant(String merchantFragment, String mccFilter, String order) {
        String soql = 'SELECT Id, Merchant_Name__c, MCC_Code__c FROM Card_Transaction__c ' +
                      'WHERE Merchant_Name__c LIKE \'%' + merchantFragment + '%\' AND MCC_Code__c = \'' +
                      mccFilter + '\' ORDER BY ' + order;
        return Database.query(soql);
    }

    public static Integer countEnriched() {
        List<Task> logs = [SELECT Id FROM Task WHERE Subject LIKE 'Enriched%'];
        return logs.size();
    }

    public static String mccLabel(String code) {
        String label;
        switch on code {
            when '5411' {
                label = 'Grocery stores';
            }
            when '5812' {
                label = 'Restaurants';
            }
            when '7995' {
                label = 'Gambling';
            }
        }
        return label;
    }

    private static Boolean legacyEnrichCheck(String merchantName) {
        return merchantName != null;
    }
}
