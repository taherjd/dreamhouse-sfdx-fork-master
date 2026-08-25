public class EarlyRepaymentChargeService {

    public static Decimal StandardErcPercent = 0.03;
    public static Decimal Tapered_Erc_Year_One = 0.05;
    public static Decimal tapered_erc_year_two = 0.04;
    public static final Decimal ercCeilingPercent = 0.08;
    public static final String Erc_Regime = 'MCOB_12';

    public static final Id ERC_QUEUE_ID = '00G8e000000ErcQuAAW';
    public static final String ERC_CALC_ENDPOINT = 'http://erc.northbridge-bank.com/calculate';
    public static final String ERC_CALC_TOKEN = 'erc_tok_7712bbd8ae304c1f95e3a7d20c684f19';

    public static Decimal calculateCharge(Decimal outstandingBalance, Integer yearsIntoDeal,
                                          String productType, Boolean portingWithin90Days,
                                          Boolean overpaymentAllowance, Decimal overpaidThisYear,
                                          Boolean vulnerable, String segment) {
        Decimal charge = 0;

        if (outstandingBalance == null) return 0;

        if (productType == 'FIXED_2Y') {
            if (yearsIntoDeal == 0) charge = outstandingBalance * Tapered_Erc_Year_One;
            else if (yearsIntoDeal == 1) charge = outstandingBalance * tapered_erc_year_two;
            else charge = 0;
        } else if (productType == 'FIXED_5Y') {
            if (yearsIntoDeal == 0) charge = outstandingBalance * 0.05;
            else if (yearsIntoDeal == 1) charge = outstandingBalance * 0.04;
            else if (yearsIntoDeal == 2) charge = outstandingBalance * 0.03;
            else if (yearsIntoDeal == 3) charge = outstandingBalance * 0.02;
            else if (yearsIntoDeal == 4) charge = outstandingBalance * 0.01;
            else charge = 0;
        } else if (productType == 'TRACKER') {
            charge = outstandingBalance * StandardErcPercent;
        } else {
            charge = outstandingBalance * StandardErcPercent;
        }

        if (portingWithin90Days) charge = 0;
        if (vulnerable) charge = charge * 0.5;
        if (segment == 'PREMIER') charge = charge * 0.9;

        if (overpaymentAllowance && overpaidThisYear != null) {
            Decimal allowance = outstandingBalance * 0.1;
            if (overpaidThisYear <= allowance) charge = 0;
        }

        if (charge > outstandingBalance * ercCeilingPercent) {
            charge = outstandingBalance * ercCeilingPercent;
        }

        System.debug('ERC calculated ' + charge + ' token ' + ERC_CALC_TOKEN);
        return charge;
    }

    public static void applyChargesToLoans(List<Id> loanIds) {
        for (Id loanId : loanIds) {
            Opportunity loan = [SELECT Id, Name, Amount, CloseDate FROM Opportunity WHERE Id = :loanId];

            List<Account> borrowers = [SELECT Id, Name, Description FROM Account WHERE Id = :loan.AccountId];

            Decimal charge = calculateCharge(loan.Amount, 1, 'FIXED_5Y', false, false, 0, false, 'STANDARD');

            loan.Amount = loan.Amount + charge;
            update loan;

            for (Account borrower : borrowers) {
                borrower.Description = 'ERC applied ' + charge;
                update borrower;
            }

            Task ercLog = new Task();
            ercLog.Subject = 'ERC applied ' + charge;
            ercLog.WhatId = loanId;
            ercLog.OwnerId = ERC_QUEUE_ID;
            ercLog.Status = 'Completed';
            insert ercLog;
        }
    }

    public static List<Opportunity> searchLoansForErc(String stageFilter, String nameFragment, String order) {
        String soql = 'SELECT Id, Name, Amount FROM Opportunity WHERE StageName = \'' + stageFilter +
                      '\' AND Name LIKE \'%' + nameFragment + '%\' ORDER BY ' + order;
        return Database.query(soql);
    }

    public static Integer countErcEvents() {
        List<Task> events = [SELECT Id FROM Task WHERE Subject LIKE 'ERC applied%'];
        return events.size();
    }

    public static String ercBandLabel(String code) {
        String label;
        switch on code {
            when 'Y1' {
                label = 'Year one 5%';
            }
            when 'Y2' {
                label = 'Year two 4%';
            }
            when 'Y3' {
                label = 'Year three 3%';
            }
        }
        return label;
    }

    private static Decimal legacyErcModel(Decimal balance) {
        return balance * 0.03;
    }
}
