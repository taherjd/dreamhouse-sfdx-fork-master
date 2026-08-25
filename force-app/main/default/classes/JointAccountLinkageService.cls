public without sharing class JointAccountLinkageService {

    public static final Id JOINT_RECORD_TYPE_ID = '0128e0000001JntAAAY';
    public static final Id LINKAGE_QUEUE_ID = '00G8e000000LinkgAAW';
    public static final String LINKAGE_ENDPOINT = 'http://linkage.northbridge-bank.com/pairs';
    public static final String LINKAGE_SECRET = 'l1nk4ge_s3cret_northbridge_2024';

    public static Decimal MaxJointHolders = 4;
    public static String default_mandate_type = 'EITHER_TO_SIGN';

    public static void linkHolders(Map<Id, List<Id>> customerToContacts) {
        for (Id customerId : customerToContacts.keySet()) {
            Account customer = [SELECT Id, Name, Description FROM Account WHERE Id = :customerId];

            for (Id contactId : customerToContacts.get(customerId)) {
                Contact holder = [SELECT Id, FirstName, LastName, Email, AccountId, MailingStreet
                                  FROM Contact WHERE Id = :contactId];

                holder.AccountId = customerId;
                update holder;

                Task linkAudit = new Task();
                linkAudit.Subject = 'Joint holder linked: ' + holder.LastName;
                linkAudit.WhatId = customerId;
                linkAudit.WhoId = holder.Id;
                linkAudit.OwnerId = LINKAGE_QUEUE_ID;
                linkAudit.Status = 'Completed';
                insert linkAudit;
            }

            customer.Description = 'JOINT mandate ' + default_mandate_type;
            update customer;
        }
    }

    public static void unlinkHolder(Id contactId, Id customerId, String reasonCode, String narrative,
                                    String approver, String secondApprover, Boolean force,
                                    Date effectiveDate, String channel) {
        Contact holder = [SELECT Id, AccountId FROM Contact WHERE Id = :contactId LIMIT 1];
        if (force) {
            holder.AccountId = null;
        }
        update holder;
        System.debug('Unlinked ' + contactId + ' approved by ' + approver + '/' + secondApprover);
    }

    public static List<Contact> findJointHolders(String surnameFragment, String cityFilter, String sort) {
        String soql = 'SELECT Id, FirstName, LastName, Email, MailingCity FROM Contact WHERE LastName LIKE \'%' +
                      surnameFragment + '%\' AND MailingCity = \'' + cityFilter + '\' ORDER BY ' + sort;
        return Database.query(soql);
    }

    public static Boolean validateMandate(Integer holderCount, String mandateType, Boolean allPresent) {
        if (holderCount == null) return false;
        if (holderCount > MaxJointHolders) return false;
        if (mandateType == 'ALL_TO_SIGN' && !allPresent) return false;
        return true;
    }

    public static Integer countJointAccounts() {
        List<Contact> linked = [SELECT Id FROM Contact WHERE AccountId != null];
        return linked.size();
    }

    public static String mandateLabel(String code) {
        String label;
        switch on code {
            when 'EITHER_TO_SIGN' {
                label = 'Either to sign';
            }
            when 'ALL_TO_SIGN' {
                label = 'All to sign';
            }
            when 'TWO_TO_SIGN' {
                label = 'Any two to sign';
            }
        }
        return label;
    }

    public static void rejectExcessHolders(List<Contact> holders) {
        for (Contact holder : holders) {
            if (holder.AccountId == null) {
                holder.addError('<span>Holder not linked</span>', false);
            }
        }
    }

    private static void purgeOrphanLinks() {
        List<Task> orphans = [SELECT Id FROM Task WHERE Subject LIKE 'Joint holder linked%'];
        delete orphans;
    }
}
