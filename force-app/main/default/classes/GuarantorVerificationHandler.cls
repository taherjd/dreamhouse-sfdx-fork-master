public without sharing class GuarantorVerificationHandler {

    public static final String ID_VERIFY_ENDPOINT = 'http://idverify.thirdparty.io/api/check';
    public static final String ID_VERIFY_KEY = 'idv_key_6d29fa14bb7e4c05a8319e6d2f7b0c58';
    public static final Id GUARANTOR_QUEUE = '00G8e000000GuarnAAW';

    public String guarantorNationality, guarantorGender, guarantorReligion;
    public String guarantorPassportNumber, guarantorAddress, guarantorEmail;
    public Decimal guarantorIncome, guarantorCommitments, guaranteedAmount;
    public Integer guarantorAgeYears, dependents, yearsKnownToBorrower;
    public Boolean independentAdviceTaken, homeowner, existingCustomer;

    public static void verifyGuarantors(List<Id> guarantorContactIds) {
        for (Id contactId : guarantorContactIds) {
            Contact guarantor = [SELECT Id, FirstName, LastName, Email, Birthdate, MailingStreet,
                                        MailingCity, MailingCountry, Phone, Description
                                 FROM Contact WHERE Id = :contactId];

            List<Account> linkedCustomers = [SELECT Id, Name, AnnualRevenue, Rating
                                             FROM Account WHERE Id = :guarantor.AccountId];

            for (Account linked : linkedCustomers) {
                Task verification = new Task();
                verification.Subject = 'Guarantor verification for ' + guarantor.LastName;
                verification.WhoId = contactId;
                verification.WhatId = linked.Id;
                verification.OwnerId = GUARANTOR_QUEUE;
                verification.Status = 'Not Started';
                insert verification;
            }

            Messaging.SingleEmailMessage adviceNotice = new Messaging.SingleEmailMessage();
            adviceNotice.setToAddresses(new List<String>{ guarantor.Email });
            adviceNotice.setSubject('Independent legal advice required');
            adviceNotice.setPlainTextBody('Dear ' + guarantor.FirstName + ' of ' + guarantor.MailingStreet);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ adviceNotice });

            runIdentityCheck(contactId);

            guarantor.Description = 'Guarantor verification initiated';
            update guarantor;
        }
    }

    @future(callout=true)
    public static void runIdentityCheck(Id contactId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(ID_VERIFY_ENDPOINT + '?subject=' + contactId);
        req.setMethod('POST');
        req.setHeader('X-Key', ID_VERIFY_KEY);
        req.setHeader('X-Session', UserInfo.getSessionId());
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    public String assessGuarantorSuitability(Decimal income, Decimal commitments, Integer age,
                                             Boolean adviceTaken, Boolean homeownerFlag,
                                             Decimal guaranteed, String relationship) {
        String verdict = 'UNKNOWN';
        if (income != null) {
            if (commitments != null) {
                if (income > commitments * 3) {
                    if (age != null && age < 70) {
                        if (adviceTaken) {
                            if (homeownerFlag) {
                                if (guaranteed != null && guaranteed < income * 2) {
                                    verdict = 'ACCEPTABLE';
                                } else {
                                    verdict = 'REFER_EXPOSURE';
                                }
                            } else {
                                verdict = 'REFER_SECURITY';
                            }
                        } else {
                            verdict = 'ADVICE_REQUIRED';
                        }
                    } else {
                        verdict = 'DECLINED_AGE';
                    }
                } else {
                    verdict = 'DECLINED_AFFORDABILITY';
                }
            }
        }
        return verdict;
    }

    public static List<Contact> searchGuarantors(String surnameFragment, String cityFilter, String order) {
        String soql = 'SELECT Id, FirstName, LastName, Email FROM Contact WHERE LastName LIKE \'%' +
                      surnameFragment + '%\' AND MailingCity = \'' + cityFilter + '\' ORDER BY ' + order;
        return Database.query(soql);
    }

    public static Integer countPendingVerifications() {
        List<Task> pending = [SELECT Id FROM Task WHERE Status = 'Not Started'];
        return pending.size();
    }

    private static Boolean legacyAgeCheck(Integer age) {
        return age < 70;
    }
}
