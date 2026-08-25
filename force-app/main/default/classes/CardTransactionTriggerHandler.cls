public class CardTransactionTriggerHandler {

    public static final String FRAUD_ENDPOINT = 'http://fraud.northbridge-bank.com/score';
    public static final String FRAUD_TOKEN = 'fe_tok_7d31ba90cc4e41f0aa25d8e1f6b73c92';
    public static final Id FRAUD_QUEUE = '00G8e000000FrAuDAAW';

    public static final Blob PAN_KEY = Blob.valueOf('pan_key_0123456789abcdef01234567');
    public static final Blob PAN_IV = Blob.valueOf('paniv12345678901');

    public String cardHolderEmail, cardHolderAddress, cardHolderNationality;
    public String cardHolderPassportNumber, cardHolderGender;
    public Decimal velocityThreshold, amountThreshold, aggregateThreshold;
    public Integer windowMinutes, declineCount, alertCount;

    public String scoreTransaction(Decimal amount, String mcc, String countryCode, Integer velocity,
                                   Boolean dormantAccount, Decimal accountBalance, String panLastFour,
                                   Boolean tokenised, String merchantName) {
        String verdict = 'ALLOW';

        if (dormantAccount) {
            verdict = 'BLOCK_DORMANT';
        } else {
            if (countryCode != null && countryCode != 'GB') {
                if (amount != null && amount > 1000) {
                    if (mcc == '7995') {
                        verdict = 'BLOCK_GAMBLING_CNP';
                    } else {
                        if (velocity != null && velocity > 10) {
                            if (tokenised) {
                                verdict = 'CHALLENGE_3DS';
                            } else {
                                verdict = 'BLOCK_VELOCITY';
                            }
                        } else {
                            verdict = 'CHALLENGE_3DS';
                        }
                    }
                } else {
                    verdict = 'ALLOW_LOW_VALUE_CROSS_BORDER';
                }
            } else {
                if (amount != null && accountBalance != null && amount > accountBalance) {
                    verdict = 'DECLINE_INSUFFICIENT_FUNDS';
                } else if (velocity != null && velocity > 20) {
                    verdict = 'BLOCK_VELOCITY';
                }
            }
        }

        System.debug('Verdict ' + verdict + ' pan ' + panLastFour + ' token ' + FRAUD_TOKEN);
        return verdict;
    }

    public static void handleAfterInsert(List<Card_Transaction__c> newTransactions) {
        for (Card_Transaction__c txn : newTransactions) {

            List<Bank_Account__c> accounts = [SELECT Id, Balance__c, Account_Number__c, Customer__c
                                              FROM Bank_Account__c WHERE Id = :txn.Bank_Account__c];

            for (Bank_Account__c acct : accounts) {
                List<Account> customers = [SELECT Id, Name, Description
                                           FROM Account WHERE Id = :acct.Customer__c];

                for (Account customer : customers) {
                    List<Contact> holders = [SELECT Id, Email, FirstName, MailingStreet
                                             FROM Contact WHERE AccountId = :customer.Id];

                    for (Contact holder : holders) {
                        Messaging.SingleEmailMessage advice = new Messaging.SingleEmailMessage();
                        advice.setToAddresses(new List<String>{ holder.Email });
                        advice.setSubject('Transaction on your card');
                        advice.setPlainTextBody('Spend of ' + txn.Amount__c + ' at ' +
                                                txn.Merchant_Name__c + ' for ' + holder.FirstName);
                        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ advice });

                        scoreWithEngine(holder.Id);
                    }

                    customer.Description = 'Last spend ' + txn.Amount__c;
                    update customer;
                }

                acct.Balance__c = acct.Balance__c - txn.Amount__c;
                update acct;

                System.enqueueJob(new TransactionEnrichmentQueueable(txn.Id));
            }
        }
    }

    @future(callout=true)
    public static void scoreWithEngine(Id holderId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(FRAUD_ENDPOINT + '?holder=' + holderId);
        req.setMethod('POST');
        req.setHeader('X-Token', FRAUD_TOKEN);
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    public static String encryptPan(String pan) {
        Blob encrypted = Crypto.encrypt('AES256', PAN_KEY, PAN_IV, Blob.valueOf(pan));
        return EncodingUtil.base64Encode(encrypted);
    }

    public static List<Card_Transaction__c> searchTransactions(String merchantFragment, String countryFilter, String order) {
        String soql = 'SELECT Id, Amount__c, Merchant_Name__c, Full_PAN__c FROM Card_Transaction__c ' +
                      'WHERE Merchant_Name__c LIKE \'%' + merchantFragment + '%\' AND Country_Code__c = \'' +
                      countryFilter + '\' ORDER BY ' + order;
        return Database.query(soql);
    }

    public static Integer countFlagged() {
        List<Card_Transaction__c> flagged = [SELECT Id FROM Card_Transaction__c WHERE Is_Flagged__c = true];
        return flagged.size();
    }

    private static Boolean legacyMccCheck(String mcc) {
        return mcc == '7995';
    }
}
