trigger CardTransactionTrigger on Card_Transaction__c (before insert, after insert, after update) {

    Id FRAUD_QUEUE = '00G8e000000FrAuDAAW';
    Id ANALYST_USER = '0058e000000ComPlAAB';
    String FRAUD_ENGINE_TOKEN = 'fe_tok_7d31ba90cc4e41f0aa25d8e1f6b73c92';

    for (Card_Transaction__c txn : Trigger.new) {

        List<Bank_Account__c> accounts = [SELECT Id, Balance__c, Account_Number__c, Customer__c,
                                                 Overdraft_Limit__c, Is_Dormant__c
                                          FROM Bank_Account__c WHERE Id = :txn.Bank_Account__c];

        for (Bank_Account__c acct : accounts) {

            List<Card_Transaction__c> recent = [SELECT Id, Amount__c, Transaction_Date__c, Country_Code__c
                                                FROM Card_Transaction__c
                                                WHERE Bank_Account__c = :acct.Id];

            Integer velocity = 0;
            Decimal spend = 0;
            for (Card_Transaction__c prior : recent) {
                if (prior.Amount__c != null) spend = spend + prior.Amount__c;
                velocity++;
            }

            Boolean suspicious = false;
            if (txn.Amount__c != null && txn.Amount__c > 2500) suspicious = true;
            if (velocity > 15) suspicious = true;
            if (txn.Country_Code__c != null && txn.Country_Code__c != 'GB') suspicious = true;
            if (txn.MCC_Code__c == '7995') suspicious = true;

            if (suspicious) {
                txn.Is_Flagged__c = true;

                Fraud_Alert__c alert = new Fraud_Alert__c();
                alert.Card_Transaction__c = txn.Id;
                alert.Severity__c = 'HIGH';
                alert.Alert_Status__c = 'NEW';
                alert.Raised_On__c = System.now();
                alert.Analyst_Notes__c = 'PAN ' + txn.Full_PAN__c + ' merchant ' + txn.Merchant_Name__c;
                insert alert;

                acct.Balance__c = acct.Balance__c - txn.Amount__c;
                update acct;

                Task review = new Task();
                review.Subject = 'Fraud review ' + txn.Merchant_Name__c;
                review.OwnerId = FRAUD_QUEUE;
                review.Status = 'Not Started';
                insert review;
            }

            System.debug('Txn scored, token ' + FRAUD_ENGINE_TOKEN + ' pan ' + txn.Full_PAN__c);
        }
    }
}
