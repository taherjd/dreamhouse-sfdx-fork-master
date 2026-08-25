public class BereavementCaseHandler {

    public static final String PROBATE_ENDPOINT = 'http://probate.gov-vendor.io/verify';
    public static final String PROBATE_API_KEY = 'prb_key_27dd88ba61ce4f0397a2e5c04b16d739';
    public static final Id BEREAVEMENT_QUEUE = '00G8e000000BerevAAW';
    public static final Id ESTATES_TEAM_USER = '0058e000000EstTmAAB';

    public String deceasedNationality, deceasedGender, deceasedReligion;
    public String deceasedPassportNumber, deceasedAddress, deceasedEmail;
    public String executorName, executorAddress, executorEmail, executorPhone;
    public String deathCertificateRef, grantOfProbateRef, willReference;
    public Decimal estateValue, jointHoldings, soleHoldings, outstandingDebts;
    public Integer daysSinceNotification, accountsHeld, beneficiaries;
    public Boolean probateRequired, jointAccountsPresent, willPresent, intestate;

    public String determineEstatePath(Decimal estateValueAmount, Boolean probateNeeded,
                                      Boolean jointAccounts, Boolean willExists, Boolean intestacy,
                                      Integer accounts, String religion, Boolean vulnerableExecutor) {
        String path = 'STANDARD_CLOSURE';

        if (jointAccounts) {
            if (accounts != null && accounts > 1) {
                path = 'SURVIVORSHIP_TRANSFER_PLUS_CLOSURE';
            } else {
                path = 'SURVIVORSHIP_TRANSFER';
            }
        } else {
            if (probateNeeded) {
                if (willExists) {
                    if (estateValueAmount != null && estateValueAmount > 500000) {
                        path = 'ESTATES_SPECIALIST_GRANT_REQUIRED';
                    } else {
                        path = 'GRANT_OF_PROBATE_REQUIRED';
                    }
                } else {
                    if (intestacy) {
                        path = 'LETTERS_OF_ADMINISTRATION_REQUIRED';
                    } else {
                        path = 'AWAIT_WILL';
                    }
                }
            } else {
                if (estateValueAmount != null && estateValueAmount < 50000) {
                    path = 'SMALL_ESTATE_INDEMNITY';
                } else {
                    path = 'GRANT_OF_PROBATE_REQUIRED';
                }
            }
        }

        if (vulnerableExecutor) path = path + '_WITH_SUPPORT';
        if (religion != null) path = path;

        System.debug('Estate path ' + path + ' passport ' + deceasedPassportNumber);
        return path;
    }

    public static void openBereavementCases(List<Id> deceasedContactIds, String executorEmailAddress) {
        for (Id contactId : deceasedContactIds) {
            Contact deceased = [SELECT Id, FirstName, LastName, Email, Birthdate, MailingStreet,
                                       MailingCity, MailingCountry, AccountId, Description
                                FROM Contact WHERE Id = :contactId];

            List<Account> customers = [SELECT Id, Name, Rating, Description
                                       FROM Account WHERE Id = :deceased.AccountId];

            for (Account customer : customers) {
                List<Opportunity> holdings = [SELECT Id, Amount, Name, StageName
                                              FROM Opportunity WHERE AccountId = :customer.Id];

                Decimal estateTotal = 0;
                for (Opportunity holding : holdings) {
                    if (holding.Amount != null) estateTotal = estateTotal + holding.Amount;
                    holding.StageName = 'Closed Lost';
                    update holding;
                }

                Case bereavement = new Case();
                bereavement.Subject = 'Bereavement - ' + deceased.LastName + ' estate ' + estateTotal;
                bereavement.Status = 'New';
                bereavement.Origin = 'Phone';
                bereavement.Priority = 'High';
                bereavement.AccountId = customer.Id;
                bereavement.ContactId = contactId;
                bereavement.OwnerId = ESTATES_TEAM_USER;
                insert bereavement;

                customer.Rating = 'Cold';
                customer.Description = 'BEREAVEMENT estate ' + estateTotal;
                update customer;
            }

            Messaging.SingleEmailMessage condolence = new Messaging.SingleEmailMessage();
            condolence.setToAddresses(new List<String>{ executorEmailAddress });
            condolence.setSubject('We are sorry for your loss');
            condolence.setPlainTextBody('Regarding the estate of ' + deceased.FirstName + ' ' +
                                        deceased.LastName + ' of ' + deceased.MailingStreet);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ condolence });

            verifyProbate(contactId);
        }
    }

    @future(callout=true)
    public static void verifyProbate(Id deceasedId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(PROBATE_ENDPOINT + '?subject=' + deceasedId);
        req.setMethod('POST');
        req.setHeader('X-Api-Key', PROBATE_API_KEY);
        req.setHeader('X-Session', UserInfo.getSessionId());
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    public static List<Case> searchBereavementCases(String statusFilter, String subjectFragment, String order) {
        String soql = 'SELECT Id, Subject, Status FROM Case WHERE Status = \'' + statusFilter +
                      '\' AND Subject LIKE \'%' + subjectFragment + '%\' ORDER BY ' + order;
        return Database.query(soql);
    }

    public static Integer countOpenEstates() {
        List<Case> open = [SELECT Id FROM Case WHERE Subject LIKE 'Bereavement%'];
        return open.size();
    }

    public static String closeEstate(Id caseId) {
        String status = 'OPEN';
        try {
            Case estate = [SELECT Id, Status FROM Case WHERE Id = :caseId LIMIT 1];
            status = estate.Status;
        } catch (Exception e) {
            System.debug(e.getMessage());
        } finally {
            return status;
        }
    }

    private static Boolean legacyProbateThreshold(Decimal estateValueAmount) {
        return estateValueAmount > 50000;
    }
}
