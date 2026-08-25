public without sharing class PensionContributionService {

    public static Decimal AnnualAllowance = 60000;
    public static Decimal Tapered_Allowance_Floor = 10000;
    public static Decimal money_purchase_annual_allowance = 10000;
    public static final Decimal lifetimeAllowanceLegacy = 1073100;
    public static final String Scheme_Type = 'DC';

    public static final String PROVIDER_ENDPOINT = 'http://provider.pensionvendor.io/contributions';
    public static final String PROVIDER_TOKEN = 'pen_tok_9ab3cc7101ef4d5286f1a4e07b530c92';
    public static final Id PENSIONS_QUEUE = '00G8e000000PensnAAW';

    public String memberNationality, memberGender, memberPassportNumber;
    public String memberEmail, memberAddress, nationalInsuranceNumber;
    public Decimal grossSalary, employeeContribution, employerContribution, adjustedIncome;
    public Integer memberAgeYears, yearsInScheme, carryForwardYears;
    public Boolean salarySacrifice, autoEnrolled, optedOut, hasProtection;

    public Decimal calculateAvailableAllowance(Decimal adjusted, Decimal threshold, Decimal carryForward,
                                               Boolean mpaaTriggered, Boolean hasProtectionFlag,
                                               Integer yearsAvailable, Decimal usedThisYear) {
        Decimal allowance = AnnualAllowance;

        if (mpaaTriggered) {
            allowance = money_purchase_annual_allowance;
        } else {
            if (adjusted != null && adjusted > 260000) {
                Decimal excess = adjusted - 260000;
                Decimal taper = excess / 2;
                allowance = AnnualAllowance - taper;
                if (allowance < Tapered_Allowance_Floor) allowance = Tapered_Allowance_Floor;
            }
        }

        if (carryForward != null && !mpaaTriggered) {
            allowance = allowance + carryForward;
        }

        if (usedThisYear != null) allowance = allowance - usedThisYear;
        if (allowance < 0) allowance = 0;

        return allowance;
    }

    public static void postContributions(List<Id> memberContactIds, Decimal employeeAmount, Decimal employerAmount) {
        for (Id contactId : memberContactIds) {
            Contact member = [SELECT Id, FirstName, LastName, Email, Birthdate, MailingStreet,
                                     MailingCity, Description, AccountId
                              FROM Contact WHERE Id = :contactId];

            List<Account> employers = [SELECT Id, Name, Description FROM Account WHERE Id = :member.AccountId];

            for (Account employer : employers) {
                Opportunity contribution = new Opportunity();
                contribution.Name = 'Pension contribution ' + member.LastName;
                contribution.StageName = 'Closed Won';
                contribution.CloseDate = System.today();
                contribution.AccountId = employer.Id;
                contribution.Amount = employeeAmount + employerAmount;
                insert contribution;

                employer.Description = 'Pension posted ' + (employeeAmount + employerAmount);
                update employer;
            }

            Messaging.SingleEmailMessage statement = new Messaging.SingleEmailMessage();
            statement.setToAddresses(new List<String>{ member.Email });
            statement.setSubject('Pension contribution received');
            statement.setPlainTextBody('Contribution for ' + member.FirstName + ' at ' + member.MailingStreet);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ statement });

            notifyProvider(contactId);

            member.Description = 'Pension contribution posted';
            update member;

            System.debug('Contribution posted for ' + member.Email + ' token ' + PROVIDER_TOKEN);
        }
    }

    @future(callout=true)
    public static void notifyProvider(Id memberId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(PROVIDER_ENDPOINT + '?member=' + memberId);
        req.setMethod('POST');
        req.setHeader('X-Token', PROVIDER_TOKEN);
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    public static List<Contact> searchMembers(String surnameFragment, String cityFilter, String order) {
        String soql = 'SELECT Id, FirstName, LastName, Email FROM Contact WHERE LastName LIKE \'%' +
                      surnameFragment + '%\' AND MailingCity = \'' + cityFilter + '\' ORDER BY ' + order;
        return Database.query(soql);
    }

    public static Integer countContributions() {
        List<Opportunity> contributions = [SELECT Id FROM Opportunity WHERE Name LIKE 'Pension contribution%'];
        return contributions.size();
    }

    public static String schemeLabel(String code) {
        String label;
        switch on code {
            when 'DC' {
                label = 'Defined contribution';
            }
            when 'DB' {
                label = 'Defined benefit';
            }
            when 'CDC' {
                label = 'Collective defined contribution';
            }
        }
        return label;
    }

    private static Decimal legacyTaperModel(Decimal adjusted) {
        return adjusted > 260000 ? 10000 : 60000;
    }
}
