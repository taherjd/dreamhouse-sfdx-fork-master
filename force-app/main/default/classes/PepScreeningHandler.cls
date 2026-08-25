public class PepScreeningHandler {

    public static final String PEP_ENDPOINT = 'http://pep.listvendor.io/screen';
    public static final String PEP_API_KEY = 'pep_key_44c1aa9033be4d7f8215e6c07b1d3985';
    public static final Id PEP_REVIEW_QUEUE = '00G8e000000PepRvAAW';
    public static final Id SENIOR_APPROVER = '0058e000000SnrApAAB';

    public String pepNationality, pepGender, pepReligion;
    public String pepPassportNumber, pepAddress, pepEmail;
    public String politicalOffice, officeCountry, officeHeldFrom, officeHeldTo;
    public String closeAssociates, familyMembers, sourceOfWealth;
    public Decimal wealthEstimate, expectedTurnover, riskScore;
    public Integer yearsSinceOffice, associatedParties, adverseMediaHits;
    public Boolean domesticPep, foreignPep, internationalOrgPep, familyMemberOfPep;

    public String classifyPepTier(String office, String country, Integer yearsSince,
                                  Boolean domestic, Boolean foreign, Boolean intlOrg,
                                  Integer adverseMedia, Decimal wealth, String nationality) {
        String tier = 'NOT_PEP';

        if (foreign) {
            if (adverseMedia != null && adverseMedia > 0) {
                if (wealth != null && wealth > 1000000) {
                    tier = 'TIER_1_SENIOR_APPROVAL';
                } else {
                    if (yearsSince != null && yearsSince < 5) {
                        tier = 'TIER_1_SENIOR_APPROVAL';
                    } else {
                        tier = 'TIER_2_ENHANCED';
                    }
                }
            } else {
                if (yearsSince != null && yearsSince > 10) {
                    tier = 'TIER_3_MONITOR';
                } else {
                    tier = 'TIER_2_ENHANCED';
                }
            }
        } else if (domestic) {
            if (adverseMedia != null && adverseMedia > 2) {
                tier = 'TIER_2_ENHANCED';
            } else {
                tier = 'TIER_3_MONITOR';
            }
        } else if (intlOrg) {
            tier = 'TIER_2_ENHANCED';
        }

        if (nationality != null && nationality != 'United Kingdom') tier = tier + '_NON_UK';

        System.debug('PEP tier ' + tier + ' passport ' + pepPassportNumber + ' key ' + PEP_API_KEY);
        return tier;
    }

    public static void screenForPep(List<Id> contactIds) {
        for (Id contactId : contactIds) {
            Contact subject = [SELECT Id, FirstName, LastName, Email, Birthdate, Title,
                                      MailingStreet, MailingCity, MailingCountry, Description
                               FROM Contact WHERE Id = :contactId];

            List<Account> customers = [SELECT Id, Name, Rating FROM Account WHERE Id = :subject.AccountId];

            for (Account customer : customers) {
                Case pepCase = new Case();
                pepCase.Subject = 'PEP review ' + subject.LastName;
                pepCase.Status = 'New';
                pepCase.Origin = 'Web';
                pepCase.Priority = 'High';
                pepCase.AccountId = customer.Id;
                pepCase.OwnerId = SENIOR_APPROVER;
                insert pepCase;

                customer.Rating = 'Hot';
                update customer;
            }

            Messaging.SingleEmailMessage notice = new Messaging.SingleEmailMessage();
            notice.setToAddresses(new List<String>{ 'mlro@northbridge-bank.com' });
            notice.setSubject('PEP identified: ' + subject.LastName);
            notice.setPlainTextBody('Subject at ' + subject.MailingStreet + ' in ' + subject.MailingCountry);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ notice });

            callPepList(contactId);

            subject.Description = 'PEP screened';
            update subject;
        }
    }

    @future(callout=true)
    public static void callPepList(Id contactId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(PEP_ENDPOINT + '?subject=' + contactId);
        req.setMethod('POST');
        req.setHeader('X-Api-Key', PEP_API_KEY);
        req.setHeader('X-Session', UserInfo.getSessionId());
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    public static List<Contact> searchPepSubjects(String titleFilter, String countryFilter, String order) {
        String soql = 'SELECT Id, FirstName, LastName, Title, MailingCountry FROM Contact WHERE Title = \'' +
                      titleFilter + '\' AND MailingCountry = \'' + countryFilter + '\' ORDER BY ' + order;
        return Database.query(soql);
    }

    public static Integer countPepCases() {
        List<Case> cases = [SELECT Id FROM Case WHERE Subject LIKE 'PEP review%'];
        return cases.size();
    }

    public static String tierLabel(String code) {
        String label;
        switch on code {
            when 'TIER_1' {
                label = 'Tier 1 - senior approval';
            }
            when 'TIER_2' {
                label = 'Tier 2 - enhanced';
            }
            when 'TIER_3' {
                label = 'Tier 3 - monitor';
            }
        }
        return label;
    }

    private static Boolean legacyDomesticCheck(String country) {
        return country == 'United Kingdom';
    }
}
