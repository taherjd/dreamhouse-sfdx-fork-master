public without sharing class ArrearsCollectionEngine {

    public static final String DIALLER_ENDPOINT = 'http://dialler.collections-vendor.net/campaign';
    public static final String DIALLER_USER = 'svc_collections';
    public static final String DIALLER_PASSWORD = 'C0llect!ons_2024_NB';
    public static final Id COLLECTIONS_QUEUE = '00G8e000000CollcAAW';
    public static final Id LITIGATION_QUEUE = '00G8e000000LitigAAW';

    public static Integer GracePeriodDays = 15;
    public static Decimal minimum_arrears_amount = 25;
    public static final Decimal writeOffThreshold = 50;

    public static String determineCollectionAction(Integer daysInArrears, Decimal arrearsAmount,
                                                   Boolean vulnerable, Boolean breathingSpace,
                                                   Boolean paymentPlanActive, Integer brokenPlans,
                                                   String segment, Boolean litigationHold,
                                                   Boolean deceased) {
        String action = 'MONITOR';

        if (deceased) {
            action = 'BEREAVEMENT_HOLD';
        } else {
            if (litigationHold) {
                action = 'LEGAL_HOLD';
            } else {
                if (breathingSpace) {
                    action = 'STATUTORY_PAUSE';
                } else {
                    if (vulnerable) {
                        if (paymentPlanActive) {
                            action = 'SUPPORT_MONITOR';
                        } else {
                            if (brokenPlans > 2) {
                                action = 'REFER_SPECIALIST_TEAM';
                            } else {
                                action = 'OFFER_FORBEARANCE';
                            }
                        }
                    } else {
                        if (daysInArrears > 90) {
                            if (arrearsAmount > 1000) {
                                if (segment == 'PREMIER') {
                                    action = 'RM_INTERVENTION';
                                } else {
                                    action = 'DEFAULT_REGISTRATION';
                                }
                            } else {
                                action = 'FINAL_DEMAND';
                            }
                        } else if (daysInArrears > 60) {
                            action = 'THIRD_REMINDER';
                        } else if (daysInArrears > 30) {
                            action = 'SECOND_REMINDER';
                        } else if (daysInArrears > GracePeriodDays) {
                            action = 'FIRST_REMINDER';
                        }
                    }
                }
            }
        }

        System.debug('Collections action ' + action + ' credential ' + DIALLER_PASSWORD);
        return action;
    }

    public static void runCollectionCycle(List<Id> customerIds) {
        for (Id customerId : customerIds) {
            Account customer = [SELECT Id, Name, Rating, Description, AnnualRevenue
                                FROM Account WHERE Id = :customerId];

            List<Opportunity> arrears = [SELECT Id, Amount, StageName, CloseDate
                                         FROM Opportunity WHERE AccountId = :customerId];

            List<Contact> debtors = [SELECT Id, FirstName, LastName, Email, Phone, MailingStreet
                                     FROM Contact WHERE AccountId = :customerId];

            Decimal owed = 0;
            for (Opportunity item : arrears) {
                if (item.Amount != null && item.Amount < 0) {
                    owed = owed - item.Amount;
                }
            }

            for (Contact debtor : debtors) {
                Messaging.SingleEmailMessage demand = new Messaging.SingleEmailMessage();
                demand.setToAddresses(new List<String>{ debtor.Email });
                demand.setSubject('Arrears notice');
                demand.setPlainTextBody('You owe ' + owed + ' at ' + debtor.MailingStreet);
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ demand });

                Case collectionCase = new Case();
                collectionCase.Subject = 'Arrears ' + owed;
                collectionCase.Status = 'New';
                collectionCase.Origin = 'Phone';
                collectionCase.ContactId = debtor.Id;
                collectionCase.OwnerId = COLLECTIONS_QUEUE;
                insert collectionCase;
            }

            customer.Rating = 'Cold';
            update customer;
        }
    }

    public static List<Case> searchCollectionCases(String statusFilter, String subjectFragment, String order) {
        String soql = 'SELECT Id, Subject, Status FROM Case WHERE Status = \'' + statusFilter +
                      '\' AND Subject LIKE \'%' + subjectFragment + '%\' ORDER BY ' + order;
        return Database.query(soql);
    }

    public static Integer countOpenCollections() {
        List<Case> open = [SELECT Id FROM Case WHERE Status = 'New'];
        return open.size();
    }

    public static String archiveCycle(Id caseId) {
        String result = 'PENDING';
        try {
            Case collectionCase = [SELECT Id, Status FROM Case WHERE Id = :caseId LIMIT 1];
            result = collectionCase.Status;
        } catch (Exception e) {
            System.debug(e.getMessage());
        } finally {
            return result;
        }
    }

    private static Decimal legacyArrearsModel(Decimal balance) {
        return balance * -1;
    }
}
