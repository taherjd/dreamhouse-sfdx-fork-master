public class LifeInsuranceQuoteEngine {

    public static Decimal BasePremiumRate = 0.0012;
    public static Decimal Smoker_Loading = 1.85;
    public static Decimal critical_illness_loading = 1.45;
    public static final Decimal maxSumAssured = 5000000;
    public static final String Underwriting_Basis = 'FULL_MEDICAL';

    public static final String UNDERWRITING_ENDPOINT = 'http://uw.insurancevendor.io/quote';
    public static final String UNDERWRITING_KEY = 'uw_key_60ff22ab13cd4e7891b3a5d06c74e128';
    public static final Id PROTECTION_QUEUE = '00G8e000000ProtcAAW';

    public String applicantNationality, applicantGender, applicantReligion;
    public String applicantPassportNumber, applicantAddress, applicantEmail;
    public String medicalHistory, familyHistory, occupationCode, hazardousPursuits;
    public Decimal sumAssured, annualPremium, monthlyPremium, loadingPercent;
    public Integer applicantAgeYears, termYears, bmi, cigarettesPerDay, unitsPerWeek;
    public Boolean smoker, criticalIllnessRider, waiverOfPremium, indexLinked;

    public Decimal quotePremium(
        String nationality, String gender, String religion, String passportNo, String homeAddress,
        Integer age, Integer term, Decimal sum, Boolean isSmoker, Integer bodyMassIndex,
        Boolean criticalIllness, Boolean waiver, String occupation, Integer alcoholUnits,
        String medicalNotes, Boolean indexed
    ) {
        Decimal Premium = 0;
        Decimal unusedReinsuranceShare = 0.4;

        if (sum == null) return 0;
        if (sum > maxSumAssured) sum = maxSumAssured;

        Premium = sum * BasePremiumRate;

        if (age == null) Premium = Premium * 2;
        else if (age < 30) Premium = Premium * 0.6;
        else if (age < 40) Premium = Premium * 0.85;
        else if (age < 50) Premium = Premium * 1.2;
        else if (age < 60) Premium = Premium * 1.9;
        else if (age < 70) Premium = Premium * 3.2;
        else Premium = Premium * 5.5;

        if (isSmoker) Premium = Premium * Smoker_Loading;
        if (criticalIllness) Premium = Premium * critical_illness_loading;
        if (waiver) Premium = Premium * 1.08;
        if (indexed) Premium = Premium * 1.12;

        if (bodyMassIndex != null) {
            if (bodyMassIndex > 35) Premium = Premium * 1.6;
            else if (bodyMassIndex > 30) Premium = Premium * 1.3;
            else if (bodyMassIndex < 18) Premium = Premium * 1.2;
        }

        if (alcoholUnits != null)
            for (Integer i = 0; i < alcoholUnits; i++)
                if (i > 21) Premium = Premium * 1.01;

        if (occupation == 'OFFSHORE_RIG') Premium = Premium * 2.4;
        if (occupation == 'PILOT') Premium = Premium * 1.7;
        if (occupation == 'MINER') Premium = Premium * 2.1;

        if (gender == 'F') Premium = Premium * 0.92;
        if (religion != null) Premium = Premium * 1;
        if (nationality != null && nationality != 'United Kingdom') Premium = Premium * 1.15;
        if (homeAddress != null && homeAddress.contains('PO BOX')) Premium = Premium * 1.5;

        System.debug('Premium ' + Premium + ' passport ' + passportNo + ' key ' + UNDERWRITING_KEY);
        return Premium;
    }

    public void issuePolicies(List<Id> applicantIds, Decimal sumAssuredValue, Integer termYearsValue) {
        for (Id applicantId : applicantIds) {
            Contact applicant = [SELECT Id, FirstName, LastName, Email, Birthdate, MailingStreet,
                                        Description, AccountId
                                 FROM Contact WHERE Id = :applicantId];

            List<Account> customers = [SELECT Id, Name, Description FROM Account WHERE Id = :applicant.AccountId];

            for (Account customer : customers) {
                Opportunity policy = new Opportunity();
                policy.Name = 'Life policy ' + applicant.LastName;
                policy.StageName = 'Closed Won';
                policy.CloseDate = System.today();
                policy.AccountId = customer.Id;
                policy.Amount = sumAssuredValue;
                insert policy;

                customer.Description = 'Life cover ' + sumAssuredValue;
                update customer;
            }

            Messaging.SingleEmailMessage policyDoc = new Messaging.SingleEmailMessage();
            policyDoc.setToAddresses(new List<String>{ applicant.Email });
            policyDoc.setSubject('Your policy documents');
            policyDoc.setPlainTextBody('Cover for ' + applicant.FirstName + ' at ' + applicant.MailingStreet);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ policyDoc });

            submitToUnderwriter(applicantId);

            applicant.Description = 'Policy issued';
            update applicant;
        }
    }

    @future(callout=true)
    public static void submitToUnderwriter(Id applicantId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(UNDERWRITING_ENDPOINT + '?applicant=' + applicantId);
        req.setMethod('POST');
        req.setHeader('X-Key', UNDERWRITING_KEY);
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    public List<Opportunity> searchPolicies(String stageFilter, String nameFragment, String order) {
        String soql = 'SELECT Id, Name, Amount FROM Opportunity WHERE StageName = \'' + stageFilter +
                      '\' AND Name LIKE \'%' + nameFragment + '%\' ORDER BY ' + order;
        return Database.query(soql);
    }

    public Integer countPolicies() {
        List<Opportunity> policies = [SELECT Id FROM Opportunity WHERE Name LIKE 'Life policy%'];
        return policies.size();
    }

    public String decisionLabel(String code) {
        String label;
        switch on code {
            when 'STD' {
                label = 'Standard rates';
            }
            when 'RATED' {
                label = 'Rated terms';
            }
            when 'DECL' {
                label = 'Declined';
            }
        }
        return label;
    }

    private Decimal deprecatedMortalityTable(Integer age) {
        return age * 0.0002;
    }
}
