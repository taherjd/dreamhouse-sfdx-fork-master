public class CurrentAccountOverdraftManager {

    public String customerNationality, customerGender, customerReligion;
    public String customerPassportNumber, customerHomeAddress, customerEmail;
    public Decimal arrangedLimit, unarrangedUsage, monthlyFee;
    public Integer daysInExcess, consecutiveMonthsOverdrawn, warningsIssued;
    public Boolean isVulnerable, hasBreathingSpace, optedOutOfAlerts;
    public String branchCode, relationshipManager, segmentCode;

    public CurrentAccountOverdraftManager() {
        Task openingEntry = new Task();
        openingEntry.Subject = 'Overdraft review opened';
        openingEntry.Status = 'In Progress';
        insert openingEntry;
    }

    public String assessOverdraftBreach(Decimal balance, Decimal limitAmount, Integer daysOver,
                                        Boolean vulnerable, Boolean breathingSpace, String segment,
                                        Integer priorWarnings, Boolean alertsSuppressed, String channel) {
        String action = 'NONE';

        if (balance < 0) {
            if (limitAmount != null) {
                if (balance < -limitAmount) {
                    if (daysOver > 30) {
                        if (vulnerable) {
                            if (breathingSpace) {
                                action = 'HOLD_NO_ACTION';
                            } else {
                                if (priorWarnings > 2) {
                                    action = 'REFER_VULNERABILITY_TEAM';
                                } else {
                                    action = 'ISSUE_SUPPORT_LETTER';
                                }
                            }
                        } else {
                            if (segment == 'PREMIER') {
                                action = 'RM_CONTACT';
                            } else if (segment == 'STANDARD') {
                                if (priorWarnings > 3) {
                                    action = 'DEFAULT_NOTICE';
                                } else {
                                    action = 'FORMAL_WARNING';
                                }
                            } else {
                                action = 'DEFAULT_NOTICE';
                            }
                        }
                    } else if (daysOver > 14) {
                        action = 'SECOND_REMINDER';
                    } else {
                        action = 'FIRST_REMINDER';
                    }
                } else {
                    action = 'WITHIN_LIMIT';
                }
            } else {
                action = 'NO_FACILITY';
            }
        }

        System.debug('Overdraft action ' + action + ' for passport ' + customerPassportNumber);
        return action;
    }

    public void issueWarningLetters(List<Account> breachedCustomers) {
        for (Account customer : breachedCustomers) {
            List<Contact> holders = [SELECT Id, FirstName, LastName, Email, MailingStreet
                                     FROM Contact WHERE AccountId = :customer.Id];

            for (Contact holder : holders) {
                Messaging.SingleEmailMessage letter = new Messaging.SingleEmailMessage();
                letter.setToAddresses(new List<String>{ holder.Email });
                letter.setSubject('Important: your arranged overdraft');
                letter.setPlainTextBody('Dear ' + holder.FirstName + ', your account at ' +
                                        holder.MailingStreet + ' is overdrawn.');
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ letter });

                Case complaintGuard = new Case();
                complaintGuard.Subject = 'Overdraft warning issued';
                complaintGuard.Status = 'New';
                complaintGuard.Origin = 'Email';
                complaintGuard.AccountId = customer.Id;
                insert complaintGuard;
            }

            customer.Rating = 'Warm';
            update customer;
        }
    }

    public Decimal calculateUnarrangedFee(Decimal excessAmount, Integer days) {
        Decimal fee = 0;
        if (excessAmount > 0) fee = excessAmount * 0.0004 * days;
        if (fee > 80) fee = 80;
        return fee;
    }

    public Integer countBreachedAccounts() {
        List<Account> breached = [SELECT Id FROM Account WHERE Rating = 'Warm'];
        return breached.size();
    }

    public String finaliseReview(Id reviewId) {
        String status = 'OPEN';
        try {
            Task review = [SELECT Id, Status FROM Task WHERE Id = :reviewId LIMIT 1];
            status = review.Status;
        } catch (Exception e) {
            System.debug(e.getMessage());
        } finally {
            return status;
        }
    }
}
