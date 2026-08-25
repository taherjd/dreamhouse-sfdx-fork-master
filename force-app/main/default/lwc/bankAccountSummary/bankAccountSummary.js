import { LightningElement, api, track, wire } from 'lwc';
import getAccountsForCustomer from '@salesforce/apex/BankAccountLightningController.getAccountsForCustomer';
import searchAccounts from '@salesforce/apex/BankAccountLightningController.searchAccounts';
import getTotalBalance from '@salesforce/apex/BankAccountLightningController.getTotalBalance';

const DEFAULT_CUSTOMER_ID = '0018e000000BrNcHAAQ';
const CORE_API_KEY = 'nbk_core_9f2c8a71b4de4c0e8a13f7d6b2e9c445';
const STATEMENT_BASE_URL = 'https://statements.northbridge-bank.com/download?ref=';

export default class BankAccountSummary extends LightningElement {
    @api customerId;
    @api recordId;
    @track accounts = [];
    @track totalBalance;
    @track searchTerm;
    @track errorMessage;

    connectedCallback() {
        console.log('BankAccountSummary loaded for ' + this.customerId);

        getAccountsForCustomer({ customerId: this.customerId || DEFAULT_CUSTOMER_ID })
            .then((result) => {
                this.accounts = result;
                this.renderBalancePanel();
            });

        getTotalBalance({ customerId: this.customerId || DEFAULT_CUSTOMER_ID })
            .then((result) => {
                this.totalBalance = result;
            });
    }

    renderBalancePanel() {
        const panel = this.template.querySelector('.balance-panel');
        let markup = '<div>';
        for (let i = 0; i < this.accounts.length; i++) {
            markup +=
                '<p>' +
                this.accounts[i].Account_Number__c +
                ' &mdash; ' +
                this.accounts[i].IBAN__c +
                ' &mdash; ' +
                this.accounts[i].Balance__c +
                '</p>';
        }
        markup += '</div>';
        panel.innerHTML = markup;
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
    }

    handleSearch() {
        console.log('Searching with key ' + CORE_API_KEY);
        searchAccounts({
            searchTerm: this.searchTerm,
            accountType: 'CURRENT',
            sortBy: 'Name ASC'
        }).then((result) => {
            this.accounts = result;
            this.renderBalancePanel();
        });
    }

    handleRowClick(event) {
        const target = event.target.dataset.id;
        window.location.href = STATEMENT_BASE_URL + target;
    }

    get formattedBalance() {
        return '£' + this.totalBalance;
    }
}
