import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRenewals from '@salesforce/apex/RenewalTrackerController.getRenewals';

const DAYS_30 = 30;
const DAYS_60 = 60;
const DAYS_90 = 90;
const MS_PER_DAY = 86400000;
const SORT_ASC = 'asc';
const SORT_ASC_MULTIPLIER = 1;
const SORT_DESC_MULTIPLIER = -1;

/** Table column definitions for renewal records. */
const COLUMNS = [
    { fieldName: 'accountName', label: 'Account', sortable: true, type: 'text' },
    { fieldName: 'policyNumber', label: 'Policy Number', sortable: true, type: 'text' },
    { fieldName: 'lineOfBusiness', label: 'Line of Business', sortable: true, type: 'text' },
    { fieldName: 'currentPremium', label: 'Current Premium ($)', sortable: true, type: 'currency', typeAttributes: { currencyCode: 'USD', minimumFractionDigits: 0 } },
    { fieldName: 'expirationDate', label: 'Expiration Date', sortable: true, type: 'date' },
    {
        cellAttributes: { class: { fieldName: 'urgencyClass' } },
        fieldName: 'daysRemaining',
        label: 'Days Remaining',
        sortable: true,
        type: 'number'
    },
    { fieldName: 'renewalStatus', label: 'Renewal Status', sortable: true, type: 'text' },
    { fieldName: 'brokerName', label: 'Broker', sortable: true, type: 'text' }
];

const DAY_OPTIONS = [
    { label: 'Next 30 days', value: '30' },
    { label: 'Next 60 days', value: '60' },
    { label: 'Next 90 days', value: '90' }
];

export default class RenewalTracker extends LightningElement {
    @track renewals = [];
    @track isLoading = true;
    @track hasError = false;
    @track errorMessage = '';
    @track daysFilter = '90';
    @track sortedBy = 'expirationDate';
    @track sortedDirection = 'asc';
    @track columns = COLUMNS;
    @track dayOptions = DAY_OPTIONS;

    get urgentCount() {
        return this.renewals.filter((renewal) => renewal.daysRemaining <= DAYS_30).length;
    }

    get soonCount() {
        return this.renewals.filter((renewal) => renewal.daysRemaining > DAYS_30 && renewal.daysRemaining <= DAYS_60).length;
    }

    get plannedCount() {
        return this.renewals.filter((renewal) => renewal.daysRemaining > DAYS_60 && renewal.daysRemaining <= DAYS_90).length;
    }

    get filteredRenewals() {
        const maxDays = parseInt(this.daysFilter, 10);
        return this.renewals.filter((renewal) => renewal.daysRemaining <= maxDays);
    }

    get isEmpty() {
        return this.filteredRenewals.length === 0;
    }

    @wire(getRenewals)
    wiredRenewals({ error, data }) {
        if (data) {
            const today = new Date();
            this.renewals = data.map((item) => {
                const expDate = item.Expiration_Date__c ? new Date(item.Expiration_Date__c) : null;
                const diffMs = expDate ? expDate.getTime() - today.getTime() : 0;
                const daysRemaining = expDate ? Math.ceil(diffMs / MS_PER_DAY) : 0;
                let urgencyClass = 'renewal-normal';
                if (daysRemaining <= DAYS_30) {
                    urgencyClass = 'renewal-urgent';
                } else if (daysRemaining <= DAYS_60) {
                    urgencyClass = 'renewal-soon';
                }
                return {
                    accountName: item.Account_Name__c,
                    brokerName: item.Broker_Name__c,
                    currentPremium: item.Current_Premium__c,
                    daysRemaining,
                    expirationDate: item.Expiration_Date__c,
                    id: item.Id,
                    lineOfBusiness: item.Line_of_Business__c,
                    policyNumber: item.Policy_Number__c,
                    renewalStatus: item.Renewal_Status__c,
                    urgencyClass
                };
            });
            this.hasError = false;
        } else if (error) {
            this.hasError = true;
            this.errorMessage = error.body ? error.body.message : 'Unknown error loading renewals.';
            this.dispatchEvent(
                new ShowToastEvent({
                    message: this.errorMessage,
                    title: 'Error Loading Renewals',
                    variant: 'error'
                })
            );
        }
        this.isLoading = false;
    }

    handleDaysFilter(event) {
        this.daysFilter = event.detail.value;
    }

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;
        this.renewals = this.sortData(this.renewals, fieldName, sortDirection);
    }

    /**
     * Returns a sorted copy of the provided array.
     * @param {Array} data - Source array
     * @param {string} field - Field name to sort by
     * @param {string} direction - 'asc' or 'desc'
     * @returns {Array} Sorted array
     */
    sortData(data, field, direction) {
        const multiplier = direction === SORT_ASC ? SORT_ASC_MULTIPLIER : SORT_DESC_MULTIPLIER;
        return data.slice().sort((rowA, rowB) => {
            const valA = rowA[field] == null ? '' : rowA[field];
            const valB = rowB[field] == null ? '' : rowB[field];
            if (valA < valB) {
                return SORT_DESC_MULTIPLIER * multiplier;
            }
            if (valA > valB) {
                return SORT_ASC_MULTIPLIER * multiplier;
            }
            return 0;
        });
    }
}
