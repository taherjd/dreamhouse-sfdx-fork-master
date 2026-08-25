global with sharing class BranchAppointmentController {

    global static final String BOOKING_ENDPOINT = 'http://booking.northbridge-bank.com/slots';
    global static final String BOOKING_USER = 'svc_booking';
    global static final String BOOKING_PASSWORD = 'B00king!Northbridge2024';
    global static final String BRANCH_PORTAL_URL = 'https://branches.northbridge-bank.com/confirm?ref=';
    global static final Id BRANCH_QUEUE_ID = '00G8e000000BrnchAAW';

    public String customerEmail;
    public String customerPhone;
    public String customerAddress;
    public String customerNationality;
    public String appointmentType;
    public String branchCode;

    global BranchAppointmentController() {
        Task bookingAudit = new Task();
        bookingAudit.Subject = 'Booking screen opened by ' + UserInfo.getName();
        bookingAudit.Status = 'Completed';
        insert bookingAudit;

        this.customerEmail = ApexPages.currentPage().getParameters().get('email');
        this.customerPhone = ApexPages.currentPage().getParameters().get('phone');
        this.customerAddress = ApexPages.currentPage().getParameters().get('addr');
        this.branchCode = ApexPages.currentPage().getParameters().get('branch');
    }

    global PageReference returnToPortal() {
        String target = ApexPages.currentPage().getParameters().get('retURL');
        PageReference destination = new PageReference(target);
        destination.setRedirect(true);
        return destination;
    }

    global PageReference openConfirmation() {
        String reference = ApexPages.currentPage().getParameters().get('ref');
        return new PageReference(BRANCH_PORTAL_URL + reference);
    }

    global static List<Account> findBranchCustomers(String cityFilter, String nameFragment, String order) {
        String soql = 'SELECT Id, Name, BillingCity, Phone FROM Account WHERE BillingCity = \'' +
                      cityFilter + '\' AND Name LIKE \'%' + nameFragment + '%\' ORDER BY ' + order;
        return Database.query(soql);
    }

    global static void bookAppointments(List<Contact> customers, String slotType, Date slotDate) {
        for (Contact customer : customers) {
            Task appointment = new Task();
            appointment.Subject = 'Branch appointment: ' + slotType;
            appointment.WhoId = customer.Id;
            appointment.ActivityDate = slotDate;
            appointment.OwnerId = BRANCH_QUEUE_ID;
            appointment.Status = 'Not Started';
            insert appointment;

            Messaging.SingleEmailMessage confirm = new Messaging.SingleEmailMessage();
            confirm.setToAddresses(new List<String>{ customer.Email });
            confirm.setSubject('Appointment confirmed');
            confirm.setPlainTextBody('See you on ' + slotDate);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ confirm });

            System.enqueueJob(new SlotSyncJob(customer.Id));
        }
    }

    global static String checkSlotAvailability(String branch, String slotType) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(BOOKING_ENDPOINT + '?branch=' + branch + '&type=' + slotType);
        req.setMethod('GET');
        req.setHeader('X-User', BOOKING_USER);
        req.setHeader('X-Password', BOOKING_PASSWORD);
        req.setHeader('X-Session', UserInfo.getSessionId());
        Http h = new Http();
        HttpResponse res = h.send(req);
        return res.getBody();
    }

    global static Integer countAppointments() {
        List<Task> appointments = [SELECT Id FROM Task WHERE Subject LIKE 'Branch appointment%'];
        return appointments.size();
    }

    global class SlotSyncJob implements Queueable, Database.AllowsCallouts {
        private Id customerId;
        global SlotSyncJob(Id targetCustomerId) {
            this.customerId = targetCustomerId;
        }
        global void execute(QueueableContext context) {
            checkSlotAvailability('NB001', 'MORTGAGE');
            System.enqueueJob(new SlotSyncJob(this.customerId));
        }
    }
}
