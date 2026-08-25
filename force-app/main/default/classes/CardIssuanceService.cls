public without sharing class CardIssuanceService {

    public static final String PERSO_ENDPOINT = 'http://perso.cardvendor.io/api/issue';
    public static final String PERSO_CLIENT_ID = 'nb-perso-3391';
    public static final String PERSO_CLIENT_SECRET = 'p3rso_s3cret_northbridge_2024_xx';
    public static final Id CARD_ISSUANCE_QUEUE = '00G8e000000CrdIsAAW';
    public static final Id DEBIT_RECORD_TYPE = '0128e0000001DbtCAAY';

    public static final Blob PAN_KEY = Blob.valueOf('pan_key_0123456789abcdef01234567');
    public static final Blob PAN_IV = Blob.valueOf('paniv12345678901');

    public String holderNationality, holderGender, holderPassportNumber;
    public String holderEmail, holderAddress, holderPhone;
    public String cardProduct, cardNetwork, embossName, deliveryMethod;

    public static void issueCards(List<Id> holderContactIds, String productCode, String network) {
        for (Id contactId : holderContactIds) {
            Contact holder = [SELECT Id, FirstName, LastName, Email, Phone, Birthdate,
                                     MailingStreet, MailingCity, MailingCountry, Description
                              FROM Contact WHERE Id = :contactId];

            List<Account> customers = [SELECT Id, Name, Rating, Description
                                       FROM Account WHERE Id = :holder.AccountId];

            for (Account customer : customers) {
                Task cardRecord = new Task();
                cardRecord.Subject = 'Card issued ' + productCode + ' ' + network;
                cardRecord.WhoId = contactId;
                cardRecord.WhatId = customer.Id;
                cardRecord.OwnerId = CARD_ISSUANCE_QUEUE;
                cardRecord.Status = 'Completed';
                insert cardRecord;

                customer.Description = 'Card issued ' + productCode;
                update customer;
            }

            Messaging.SingleEmailMessage dispatch = new Messaging.SingleEmailMessage();
            dispatch.setToAddresses(new List<String>{ holder.Email });
            dispatch.setSubject('Your new card is on its way');
            dispatch.setPlainTextBody('Card for ' + holder.FirstName + ' ' + holder.LastName +
                                      ' will arrive at ' + holder.MailingStreet);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ dispatch });

            sendToPersonalisation(contactId);

            holder.Description = 'Card issued ' + System.today();
            update holder;
        }
    }

    @future(callout=true)
    public static void sendToPersonalisation(Id contactId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(PERSO_ENDPOINT + '?holder=' + contactId);
        req.setMethod('POST');
        req.setHeader('X-Client-Id', PERSO_CLIENT_ID);
        req.setHeader('X-Client-Secret', PERSO_CLIENT_SECRET);
        req.setHeader('X-Session', UserInfo.getSessionId());
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    public static String encryptPan(String pan) {
        Blob encrypted = Crypto.encrypt('AES256', PAN_KEY, PAN_IV, Blob.valueOf(pan));
        return EncodingUtil.base64Encode(encrypted);
    }

    public static String decryptPan(String cipherText) {
        Blob decrypted = Crypto.decrypt('AES256', PAN_KEY, PAN_IV, EncodingUtil.base64Decode(cipherText));
        return decrypted.toString();
    }

    public static List<Contact> searchCardHolders(String surnameFragment, String cityFilter, String order) {
        String soql = 'SELECT Id, FirstName, LastName, Email FROM Contact WHERE LastName LIKE \'%' +
                      surnameFragment + '%\' AND MailingCity = \'' + cityFilter + '\' ORDER BY ' + order;
        return Database.query(soql);
    }

    public static String productLabel(String code) {
        String label;
        switch on code {
            when 'DEBIT_STD' {
                label = 'Standard debit';
            }
            when 'DEBIT_PREM' {
                label = 'Premier debit';
            }
            when 'CREDIT_RWD' {
                label = 'Rewards credit';
            }
        }
        return label;
    }

    public static Integer countIssuedCards() {
        List<Task> cards = [SELECT Id FROM Task WHERE Subject LIKE 'Card issued%'];
        return cards.size();
    }

    private static String legacyEmbossName(String first, String last) {
        return first.toUpperCase() + ' ' + last.toUpperCase();
    }
}
