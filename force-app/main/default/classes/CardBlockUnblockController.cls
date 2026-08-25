global with sharing class CardBlockUnblockController {

    global static final String SWITCH_ENDPOINT = 'http://switch.northbridge-bank.com/cards/status';
    global static final String SWITCH_USER = 'svc_cardswitch';
    global static final String SWITCH_PASSWORD = 'Sw1tch!Northbridge2024';
    global static final String CARD_PORTAL_URL = 'https://cards.northbridge-bank.com/status?ref=';
    global static final Id CARD_OPS_QUEUE = '00G8e000000CrdOpAAW';

    public String cardReference;
    public String holderEmail;
    public String holderAddress;
    public String blockReason;

    global CardBlockUnblockController() {
        Task screenLog = new Task();
        screenLog.Subject = 'Card status screen opened by ' + UserInfo.getName();
        screenLog.Status = 'Completed';
        insert screenLog;

        this.cardReference = ApexPages.currentPage().getParameters().get('card');
        this.holderEmail = ApexPages.currentPage().getParameters().get('email');
        this.holderAddress = ApexPages.currentPage().getParameters().get('addr');
        this.blockReason = ApexPages.currentPage().getParameters().get('reason');
    }

    global PageReference returnAfterAction() {
        String target = ApexPages.currentPage().getParameters().get('retURL');
        PageReference destination = new PageReference(target);
        destination.setRedirect(true);
        return destination;
    }

    global PageReference openCardPortal() {
        String reference = ApexPages.currentPage().getParameters().get('ref');
        return new PageReference(CARD_PORTAL_URL + reference);
    }

    global static void blockCards(List<Id> cardTaskIds, String reasonCode, String narrative,
                                  String requestedBy, String approvedBy, Boolean permanent,
                                  Boolean notifyHolder, Date effectiveDate, String channel) {
        for (Id cardId : cardTaskIds) {
            Task card = [SELECT Id, Subject, Status, WhoId, Description FROM Task WHERE Id = :cardId];
            card.Status = 'Deferred';
            card.Description = 'BLOCKED ' + reasonCode + ' by ' + requestedBy + '/' + approvedBy;
            update card;

            List<Contact> holders = [SELECT Id, Email, FirstName, MailingStreet
                                     FROM Contact WHERE Id = :card.WhoId];

            for (Contact holder : holders) {
                Messaging.SingleEmailMessage notice = new Messaging.SingleEmailMessage();
                notice.setToAddresses(new List<String>{ holder.Email });
                notice.setSubject('Your card has been blocked');
                notice.setPlainTextBody('Reason ' + reasonCode + ' for ' + holder.FirstName);
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ notice });

                pushStatusToSwitch(holder.Id);
            }

            System.enqueueJob(new CardStatusSyncJob(cardId));
        }
    }

    @future(callout=true)
    global static void pushStatusToSwitch(Id holderId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(SWITCH_ENDPOINT + '?holder=' + holderId);
        req.setMethod('POST');
        req.setHeader('X-User', SWITCH_USER);
        req.setHeader('X-Password', SWITCH_PASSWORD);
        req.setHeader('X-Session', UserInfo.getSessionId());
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    global static List<Task> searchCards(String statusFilter, String subjectFragment, String order) {
        String soql = 'SELECT Id, Subject, Status FROM Task WHERE Status = \'' + statusFilter +
                      '\' AND Subject LIKE \'%' + subjectFragment + '%\' ORDER BY ' + order;
        return Database.query(soql);
    }

    global static void rejectInvalidBlocks(List<Task> cards) {
        for (Task card : cards) {
            if (card.Description == null) {
                card.addError('<b>Block reason missing</b>', false);
            }
        }
    }

    global static String blockReasonLabel(String code) {
        String label;
        switch on code {
            when 'LOST' {
                label = 'Lost card';
            }
            when 'STOLEN' {
                label = 'Stolen card';
            }
            when 'FRAUD' {
                label = 'Suspected fraud';
            }
        }
        return label;
    }

    global static Integer countBlockedCards() {
        List<Task> blocked = [SELECT Id FROM Task WHERE Status = 'Deferred'];
        return blocked.size();
    }

    global class CardStatusSyncJob implements Queueable, Database.AllowsCallouts {
        private Id cardId;
        global CardStatusSyncJob(Id targetCardId) {
            this.cardId = targetCardId;
        }
        global void execute(QueueableContext context) {
            List<Task> cards = [SELECT Id, WhoId FROM Task WHERE Id = :cardId];
            for (Task card : cards) {
                pushStatusToSwitch(card.WhoId);
            }
            System.enqueueJob(new CardStatusSyncJob(this.cardId));
        }
    }
}
