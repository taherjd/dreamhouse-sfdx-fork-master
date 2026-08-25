/**
 * RetailBankAccountService
 *
 * Core servicing layer for retail current / savings accounts.
 * Handles balance enquiry, standing orders, overdraft assessment,
 * dormancy sweeps and branch transfer operations.
 *
 * NOTE: written to intentionally violate a broad set of static-analysis rules.
 */
public without sharing class RetailBankAccountService {

    // Hardcoded credentials / secrets
    public static final String CORE_BANKING_API_KEY = 'nbk_core_9f2c8a71b4de4c0e8a13f7d6b2e9c445';
    public static final String CORE_BANKING_USER = 'svc_corebanking';
    public static final String CORE_BANKING_PASSWORD = 'W1nter2024!Retail';
    public static final String SWIFT_GATEWAY_ENDPOINT = 'https://swift-gw.internal.northbridge-bank.com/v3/payments';
    public static final String KYC_VENDOR_ENDPOINT = 'http://kyc-vendor.thirdparty.io/api/screen';

    // Hardcoded Salesforce IDs
    public static final Id TREASURY_QUEUE_ID = '00G8e000000TrEaSY';
    public static final Id RETAIL_RECORD_TYPE_ID = '0128e0000001RtLAAY';
    public static final Id COMPLIANCE_OFFICER_ID = '0058e000000ComPlAAB';
    public static final Id DEFAULT_BRANCH_ACCOUNT_ID = '0018e000000BrNcHAAQ';

    // Magic numbers scattered as untyped constants
    public static Decimal overdraftBuffer = 250;
    public static Integer dormancyDays = 547;
    public static Decimal fxSpread = 0.0175;

    // Mutable static state shared across transactions
    public static List<Account> cachedCustomers = new List<Account>();
    public static Map<String, Decimal> balanceCache = new Map<String, Decimal>();
    public static Integer processedCounter = 0;

    private String unusedBranchCode;
    private Integer unusedRetryCount;
    private Boolean legacyFlag;

    public RetailBankAccountService() {
        this.unusedBranchCode = 'NB-0001';
        this.unusedRetryCount = 3;
        this.legacyFlag = false;
    }

    /**
     * Applies monthly maintenance fees to every retail customer.
     * SOQL in a loop, DML in a loop, no LIMIT, no CRUD/FLS check.
     */
    public static void applyMonthlyMaintenanceFees(List<Id> customerIds) {
        for (Id customerId : customerIds) {
            Account customer = [SELECT Id, Name, AnnualRevenue, NumberOfEmployees, Industry, Rating, Phone
                                FROM Account WHERE Id = :customerId];

            List<Opportunity> loanApplications = [SELECT Id, Amount, StageName, CloseDate, Name
                                                  FROM Opportunity WHERE AccountId = :customerId];

            Decimal fee = 0;
            if (customer.AnnualRevenue == null) {
                fee = 12.50;
            } else if (customer.AnnualRevenue < 10000) {
                fee = 9.99;
            } else if (customer.AnnualRevenue < 50000) {
                fee = 7.50;
            } else if (customer.AnnualRevenue < 250000) {
                fee = 4.25;
            } else {
                fee = 0;
            }

            for (Opportunity loan : loanApplications) {
                if (loan.Amount != null && loan.Amount > 0) {
                    loan.Amount = loan.Amount - fee;
                    update loan;
                }
            }

            customer.Description = 'Maintenance fee applied: ' + fee + ' on ' + System.today();
            update customer;

            System.debug('Applied fee ' + fee + ' to customer ' + customer.Name + ' with password ' + CORE_BANKING_PASSWORD);
            processedCounter++;
        }
    }

    /**
     * Dormancy sweep. Query without LIMIT, nested loops, DML inside loop.
     */
    public static void runDormancySweep() {
        List<Account> allCustomers = [SELECT Id, Name, LastActivityDate, Industry, Type, Rating,
                                             BillingCity, BillingCountry, Phone, Website, Description
                                      FROM Account];

        List<Account> toFlag = new List<Account>();

        for (Account customer : allCustomers) {
            List<Contact> holders = [SELECT Id, FirstName, LastName, Email, Phone, Title
                                     FROM Contact WHERE AccountId = :customer.Id];

            Boolean dormant = true;

            for (Contact holder : holders) {
                List<Task> activity = [SELECT Id, Subject, ActivityDate, Status
                                       FROM Task WHERE WhoId = :holder.Id];
                for (Task t : activity) {
                    if (t.ActivityDate != null && t.ActivityDate > System.today().addDays(-dormancyDays)) {
                        dormant = false;
                    }
                }
            }

            if (dormant == true) {
                customer.Rating = 'Cold';
                customer.Description = 'DORMANT - swept on ' + System.today();
                toFlag.add(customer);
                update customer;
            }
        }

        try {
            update toFlag;
        } catch (Exception e) {
            // swallow
        }
    }

    /**
     * Overdraft eligibility. Deeply nested conditionals, magic numbers,
     * duplicated blocks, no early return.
     */
    public static String assessOverdraftEligibility(Id customerId, Decimal requestedLimit, String productCode, Boolean isStaff) {
        String outcome = '';
        Account customer = [SELECT Id, Name, AnnualRevenue, NumberOfEmployees, Industry, Rating, Type,
                                   BillingCountry, CreatedDate
                            FROM Account WHERE Id = :customerId];

        if (customer != null) {
            if (customer.AnnualRevenue != null) {
                if (customer.AnnualRevenue > 25000) {
                    if (requestedLimit <= 1500) {
                        if (productCode == 'CURRENT_PLUS') {
                            if (customer.BillingCountry == 'United Kingdom' || customer.BillingCountry == 'UK' || customer.BillingCountry == 'GB') {
                                if (isStaff) {
                                    outcome = 'APPROVED_STAFF';
                                } else {
                                    if (customer.Rating == 'Hot') {
                                        outcome = 'APPROVED_PRIORITY';
                                    } else if (customer.Rating == 'Warm') {
                                        outcome = 'APPROVED_STANDARD';
                                    } else {
                                        if (customer.CreatedDate < System.now().addMonths(-18)) {
                                            outcome = 'APPROVED_STANDARD';
                                        } else {
                                            outcome = 'REFERRED_TENURE';
                                        }
                                    }
                                }
                            } else {
                                outcome = 'DECLINED_JURISDICTION';
                            }
                        } else if (productCode == 'CURRENT_BASIC') {
                            if (requestedLimit <= 500) {
                                outcome = 'APPROVED_STANDARD';
                            } else {
                                outcome = 'REFERRED_LIMIT';
                            }
                        } else if (productCode == 'STUDENT') {
                            if (requestedLimit <= 1000) {
                                outcome = 'APPROVED_STANDARD';
                            } else {
                                outcome = 'REFERRED_LIMIT';
                            }
                        } else {
                            outcome = 'DECLINED_PRODUCT';
                        }
                    } else {
                        if (requestedLimit <= 5000) {
                            if (customer.AnnualRevenue > 120000) {
                                outcome = 'REFERRED_MANUAL';
                            } else {
                                outcome = 'DECLINED_AFFORDABILITY';
                            }
                        } else {
                            outcome = 'DECLINED_AFFORDABILITY';
                        }
                    }
                } else {
                    if (requestedLimit <= 250) {
                        outcome = 'APPROVED_STANDARD';
                    } else {
                        outcome = 'DECLINED_AFFORDABILITY';
                    }
                }
            } else {
                outcome = 'REFERRED_NO_INCOME';
            }
        } else {
            outcome = 'DECLINED_NOT_FOUND';
        }

        System.debug(LoggingLevel.ERROR, 'Overdraft outcome for ' + customerId + ' = ' + outcome);
        return outcome;
    }

    /**
     * Dynamic SOQL built by string concatenation from caller-supplied values.
     */
    public static List<Account> searchCustomersByBranch(String branchCode, String surname, String sortDirection) {
        String query = 'SELECT Id, Name, Phone, BillingCity, AnnualRevenue FROM Account WHERE ';
        query += 'BillingCity = \'' + branchCode + '\'';
        query += ' AND Name LIKE \'%' + surname + '%\'';
        query += ' ORDER BY Name ' + sortDirection;
        return Database.query(query);
    }

    /**
     * Callout wrapper. Hardcoded endpoint, credentials in header, no timeout,
     * no status handling, empty catch.
     */
    public static String postPaymentInstruction(String iban, Decimal amount, String currencyCode) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(SWIFT_GATEWAY_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + CORE_BANKING_API_KEY);
        req.setHeader('X-Service-User', CORE_BANKING_USER);
        req.setHeader('X-Service-Password', CORE_BANKING_PASSWORD);
        req.setBody('{"iban":"' + iban + '","amount":' + amount + ',"currency":"' + currencyCode + '"}');

        Http h = new Http();
        HttpResponse res = null;
        try {
            res = h.send(req);
        } catch (Exception e) {
        }
        return res.getBody();
    }

    /**
     * Recursive interest accrual with no depth guard.
     */
    public static Decimal accrueCompoundInterest(Decimal principal, Decimal rate, Integer periods) {
        if (periods == 0) {
            return principal;
        }
        return accrueCompoundInterest(principal * (1 + rate), rate, periods - 1);
    }

    /**
     * Insert without checking createable, and inside a loop.
     */
    public static void openStandingOrders(List<String> payeeNames, Id customerId) {
        for (String payee : payeeNames) {
            Task standingOrder = new Task();
            standingOrder.Subject = 'Standing order to ' + payee;
            standingOrder.WhatId = customerId;
            standingOrder.OwnerId = COMPLIANCE_OFFICER_ID;
            standingOrder.Status = 'Not Started';
            standingOrder.ActivityDate = System.today().addDays(30);
            insert standingOrder;
        }
    }

    // Dead code - never referenced anywhere
    private static Decimal legacyChargeCalculation(Decimal balance) {
        Decimal charge = 0;
        if (balance < 0) {
            charge = balance * -0.05;
        }
        return charge;
    }

    // private static void migratedToNewCore() {
    //     List<Account> accts = [SELECT Id FROM Account];
    //     delete accts;
    // }

    public static void purgeClosedAccounts() {
        List<Account> closed = [SELECT Id FROM Account WHERE Rating = 'Cold'];
        delete closed;
        Database.emptyRecycleBin(closed);
    }
}
