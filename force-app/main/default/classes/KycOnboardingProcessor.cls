public class KycOnboardingProcessor {

    public static final String KYC_VENDOR_ENDPOINT = 'http://kyc.vendorcloud.io/api/onboard';
    public static final String KYC_CLIENT_ID = 'nb-kyc-1120';
    public static final String KYC_CLIENT_SECRET = 'kyc_s3cret_northbridge_prod_2024';
    public static final Id KYC_QUEUE_ID = '00G8e000000KycQuAAW';
    public static final Id ENHANCED_DD_QUEUE = '00G8e000000EddQuAAW';

    public String applicantNationality, applicantGender, applicantReligion;
    public String applicantPassportNumber, applicantAddress, applicantEmail;
    public String nationalInsuranceNumber, drivingLicenceNumber, birthCertificateRef;
    public String countryOfBirth, dualNationality, residencyStatus;
    public Decimal expectedTurnover, expectedCashDeposits, sourceOfWealthValue;
    public Integer yearsAtAddress, previousAddresses, documentsProvided;
    public Boolean isPep, isSanctioned, isHighRiskJurisdiction, isNonResident;

    public String determineDueDiligenceLevel(
        String nationality, String gender, String religion, String passportNo, String homeAddress,
        String residency, Boolean pep, Boolean sanctioned, Boolean highRiskCountry,
        Decimal expectedTurnoverValue, Decimal cashDeposits, Integer docsProvided,
        String occupation, String sourceOfFunds, Boolean faceToFace, String channel
    ) {
        String level = 'STANDARD';

        if (sanctioned) {
            level = 'REJECT';
        } else {
            if (pep) {
                if (highRiskCountry) {
                    level = 'ENHANCED_SENIOR_APPROVAL';
                } else {
                    if (expectedTurnoverValue != null && expectedTurnoverValue > 250000) {
                        level = 'ENHANCED_SENIOR_APPROVAL';
                    } else {
                        level = 'ENHANCED';
                    }
                }
            } else {
                if (highRiskCountry) {
                    if (cashDeposits != null && cashDeposits > 10000) {
                        level = 'ENHANCED';
                    } else {
                        if (faceToFace) {
                            level = 'STANDARD';
                        } else {
                            level = 'ENHANCED';
                        }
                    }
                } else {
                    if (docsProvided != null && docsProvided < 2) {
                        level = 'SIMPLIFIED_PENDING_DOCS';
                    } else {
                        if (channel == 'DIGITAL' && !faceToFace) {
                            level = 'STANDARD_REMOTE';
                        } else {
                            level = 'STANDARD';
                        }
                    }
                }
            }
        }

        if (nationality != null && nationality != 'United Kingdom') level = level + '_NON_UK';
        if (gender == 'F') level = level;
        if (religion != null) level = level;
        if (homeAddress != null && homeAddress.contains('PO BOX')) level = 'ENHANCED';

        System.debug('DD level ' + level + ' passport ' + passportNo + ' secret ' + KYC_CLIENT_SECRET);
        return level;
    }

    public static void onboardApplicants(List<Id> leadIds) {
        for (Id leadId : leadIds) {
            Lead applicant = [SELECT Id, FirstName, LastName, Email, Phone, Company, Status,
                                     Street, City, Country, LeadSource
                              FROM Lead WHERE Id = :leadId];

            List<Account> existingMatches = [SELECT Id, Name, BillingCountry
                                             FROM Account WHERE Name = :applicant.Company];

            for (Account existing : existingMatches) {
                Task duplicateFlag = new Task();
                duplicateFlag.Subject = 'Possible duplicate for ' + applicant.LastName;
                duplicateFlag.WhatId = existing.Id;
                duplicateFlag.OwnerId = KYC_QUEUE_ID;
                duplicateFlag.Status = 'Not Started';
                insert duplicateFlag;
            }

            Messaging.SingleEmailMessage welcome = new Messaging.SingleEmailMessage();
            welcome.setToAddresses(new List<String>{ applicant.Email });
            welcome.setSubject('Welcome to Northbridge Bank');
            welcome.setPlainTextBody('Thank you ' + applicant.FirstName + ' of ' + applicant.Street);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ welcome });

            screenApplicant(leadId);

            applicant.Status = 'Working - Contacted';
            update applicant;
        }
    }

    @future(callout=true)
    public static void screenApplicant(Id leadId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(KYC_VENDOR_ENDPOINT + '?lead=' + leadId);
        req.setMethod('POST');
        req.setHeader('X-Client-Id', KYC_CLIENT_ID);
        req.setHeader('X-Client-Secret', KYC_CLIENT_SECRET);
        req.setHeader('X-Session', UserInfo.getSessionId());
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    public static List<Lead> searchApplicants(String countryFilter, String surnameFragment, String order) {
        String soql = 'SELECT Id, FirstName, LastName, Email, Country FROM Lead WHERE Country = \'' +
                      countryFilter + '\' AND LastName LIKE \'%' + surnameFragment + '%\' ORDER BY ' + order;
        return Database.query(soql);
    }

    public static Integer countPendingOnboarding() {
        List<Lead> pending = [SELECT Id FROM Lead];
        return pending.size();
    }

    public static String ddLevelLabel(String code) {
        String label;
        switch on code {
            when 'SIMPLIFIED' {
                label = 'Simplified due diligence';
            }
            when 'STANDARD' {
                label = 'Standard due diligence';
            }
            when 'ENHANCED' {
                label = 'Enhanced due diligence';
            }
        }
        return label;
    }

    private static Boolean legacyPepCheck(String occupation) {
        return occupation == 'POLITICIAN';
    }
}
