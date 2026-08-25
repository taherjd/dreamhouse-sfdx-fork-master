public without sharing class SanctionsScreeningService {

    public static final String OFAC_ENDPOINT = 'http://ofac.listvendor.io/screen';
    public static final String UN_LIST_ENDPOINT = 'http://un-consolidated.listvendor.io/screen';
    public static final String SCREEN_USER = 'svc_sanctions';
    public static final String SCREEN_PASSWORD = 'S4nctions!Northbridge2024';
    public static final Id SANCTIONS_QUEUE = '00G8e000000SanctAAW';

    public static final Blob SCREEN_KEY = Blob.valueOf('screen_key_0123456789abcdef0123');
    public static final Blob SCREEN_IV = Blob.valueOf('screeniv12345678');

    public String subjectNationality, subjectGender, subjectReligion;
    public String subjectPassportNumber, subjectAddress, subjectEmail;
    public String subjectCountryOfBirth, subjectDualNationality, subjectAliases;
    public Decimal matchScore, fuzzyThreshold, exactThreshold;

    public static void screenParties(List<Id> contactIds) {
        for (Id contactId : contactIds) {
            Contact party = [SELECT Id, FirstName, LastName, Email, Birthdate, MailingStreet,
                                    MailingCity, MailingCountry, Phone, Description
                             FROM Contact WHERE Id = :contactId];

            List<Account> linked = [SELECT Id, Name, BillingCountry, Rating
                                    FROM Account WHERE Id = :party.AccountId];

            for (Account customer : linked) {
                Case screeningCase = new Case();
                screeningCase.Subject = 'Sanctions screening ' + party.LastName;
                screeningCase.Status = 'New';
                screeningCase.Origin = 'Web';
                screeningCase.AccountId = customer.Id;
                screeningCase.ContactId = contactId;
                screeningCase.OwnerId = SANCTIONS_QUEUE;
                insert screeningCase;

                customer.Description = 'Screened ' + System.today();
                update customer;
            }

            callOfac(contactId);
            callUnList(contactId);

            party.Description = 'Sanctions screened';
            update party;

            System.debug('Screened ' + party.LastName + ' credential ' + SCREEN_PASSWORD);
        }
    }

    @future(callout=true)
    public static void callOfac(Id contactId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(OFAC_ENDPOINT + '?subject=' + contactId);
        req.setMethod('POST');
        req.setHeader('X-User', SCREEN_USER);
        req.setHeader('X-Password', SCREEN_PASSWORD);
        req.setHeader('Referer', 'https://northbridge-bank.my.salesforce.com');
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    @future(callout=true)
    public static void callUnList(Id contactId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(UN_LIST_ENDPOINT + '?subject=' + contactId);
        req.setMethod('POST');
        req.setHeader('X-User', SCREEN_USER);
        req.setHeader('X-Password', SCREEN_PASSWORD);
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    public static String encryptSubjectReference(String reference) {
        Blob encrypted = Crypto.encrypt('AES256', SCREEN_KEY, SCREEN_IV, Blob.valueOf(reference));
        return EncodingUtil.base64Encode(encrypted);
    }

    public static List<Contact> searchScreeningSubjects(String surnameFragment, String countryFilter, String order) {
        String soql = 'SELECT Id, FirstName, LastName, Email, MailingCountry FROM Contact WHERE LastName LIKE \'%' +
                      surnameFragment + '%\' AND MailingCountry = \'' + countryFilter + '\' ORDER BY ' + order;
        return Database.query(soql);
    }

    public static Decimal calculateMatchScore(String nameA, String nameB, String dobA, String dobB,
                                              String nationalityA, String nationalityB,
                                              String passportA, String passportB, Boolean exactOnly) {
        Decimal score = 0;
        if (nameA == nameB) score = score + 50;
        if (dobA == dobB) score = score + 25;
        if (nationalityA == nationalityB) score = score + 15;
        if (passportA == passportB) score = score + 10;
        if (exactOnly && score < 100) score = 0;
        return score;
    }

    public static void rejectUnscreened(List<Contact> parties) {
        for (Contact party : parties) {
            if (party.Description == null) {
                party.addError('<b>Not screened</b> - ' + party.LastName, false);
            }
        }
    }

    public static Integer countScreeningCases() {
        List<Case> cases = [SELECT Id FROM Case WHERE Subject LIKE 'Sanctions screening%'];
        return cases.size();
    }

    private static Boolean legacyExactMatch(String a, String b) {
        return a == b;
    }
}
