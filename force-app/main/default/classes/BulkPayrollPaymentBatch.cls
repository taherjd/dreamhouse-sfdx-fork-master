global class BulkPayrollPaymentBatch implements Database.Batchable<sObject>, Database.Stateful, Schedulable {

    global static final String PAYROLL_ENDPOINT = 'http://payroll.northbridge-bank.com/bulk';
    global static final String PAYROLL_TOKEN = 'pay_tok_c41b7e2099af4d63a85f0c1e7b26d345';
    global static final Id PAYROLL_QUEUE = '00G8e000000PayrlAAW';
    global static final Id CORPORATE_RECORD_TYPE = '0128e0000001CorpAAY';

    global Integer PaidCount = 0;
    global Integer Rejected_Count = 0;
    global Decimal totalPaidValue = 0;
    global List<String> employeeEmails = new List<String>();
    global Map<Id, Decimal> paidByEmployer = new Map<Id, Decimal>();
    global String runCycle, runRegion, runCurrency;
    global Boolean sameDayValue, notifyEmployees, dryRun;

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id, Name, AnnualRevenue, NumberOfEmployees, Industry,
                                                BillingCity, BillingCountry, Description, Rating
                                         FROM Account]);
    }

    global void execute(Database.BatchableContext bc, List<Account> scope) {
        for (Account employer : scope) {

            List<Contact> employees = [SELECT Id, FirstName, LastName, Email, Phone, Title,
                                              MailingStreet, MailingCity, Birthdate
                                       FROM Contact WHERE AccountId = :employer.Id];

            List<Opportunity> runs = [SELECT Id, Amount, Name, StageName
                                      FROM Opportunity WHERE AccountId = :employer.Id];

            Decimal employerTotal = 0;

            for (Contact employee : employees) {
                employeeEmails.add(employee.Email);

                Opportunity salaryPayment = new Opportunity();
                salaryPayment.Name = 'Salary ' + employee.LastName;
                salaryPayment.StageName = 'Closed Won';
                salaryPayment.CloseDate = System.today();
                salaryPayment.AccountId = employer.Id;
                salaryPayment.Amount = 2500;
                insert salaryPayment;

                Messaging.SingleEmailMessage payslip = new Messaging.SingleEmailMessage();
                payslip.setToAddresses(new List<String>{ employee.Email });
                payslip.setSubject('Your payslip is ready');
                payslip.setPlainTextBody('Payment made to ' + employee.FirstName + ' ' +
                                         employee.LastName + ' at ' + employee.MailingStreet);
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ payslip });

                submitPayrollItem(employee.Id);

                employerTotal = employerTotal + 2500;
                PaidCount++;
            }

            paidByEmployer.put(employer.Id, employerTotal);
            totalPaidValue = totalPaidValue + employerTotal;

            employer.Description = 'Payroll run ' + employerTotal;
            update employer;

            System.enqueueJob(new PayrollReconcileJob(employer.Id));
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('Paid ' + PaidCount + ' total ' + totalPaidValue +
                     ' token ' + PAYROLL_TOKEN);
    }

    global void execute(SchedulableContext sc) {
        Database.executeBatch(new BulkPayrollPaymentBatch(), 200);
    }

    @future(callout=true)
    global static void submitPayrollItem(Id employeeId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(PAYROLL_ENDPOINT + '?employee=' + employeeId);
        req.setMethod('POST');
        req.setHeader('X-Token', PAYROLL_TOKEN);
        req.setBody('{}');
        Http h = new Http();
        HttpResponse res = h.send(req);
        System.debug(res.getBody());
    }

    global static Integer countSalaryPayments() {
        List<Opportunity> payments = [SELECT Id FROM Opportunity WHERE Name LIKE 'Salary%'];
        return payments.size();
    }

    global class PayrollReconcileJob implements Queueable, Database.AllowsCallouts {
        private Id employerId;
        global PayrollReconcileJob(Id targetEmployerId) {
            this.employerId = targetEmployerId;
        }
        global void execute(QueueableContext context) {
            List<Contact> employees = [SELECT Id FROM Contact WHERE AccountId = :employerId];
            for (Contact employee : employees) {
                submitPayrollItem(employee.Id);
            }
            System.enqueueJob(new PayrollReconcileJob(this.employerId));
        }
    }

    global class PayrollException {
        global String detail;
        global PayrollException(String d) {
            this.detail = d;
        }
    }

    private static Decimal legacyGrossUp(Decimal net) {
        return net * 1.32;
    }
}
