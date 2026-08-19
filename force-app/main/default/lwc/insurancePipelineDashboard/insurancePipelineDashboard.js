import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSubmissions from '@salesforce/apex/InsurancePipelineController.getSubmissions';

/** Column definitions for the submission pipeline datatable. */
const COLUMNS = [
    { fieldName: 'accountName', label: 'Account', sortable: true, type: 'text' },
    { fieldName: 'submissionNumber', label: 'Submission #', sortable: true, type: 'text' },
    { fieldName: 'lineOfBusiness', label: 'Line of Business', sortable: true, type: 'text' },
    { fieldName: 'premium', label: 'Premium ($)', sortable: true, type: 'currency', typeAttributes: { currencyCode: 'USD', minimumFractionDigits: 0 } },
    { fieldName: 'status', label: 'Status', sortable: true, type: 'text' },
    { fieldName: 'effectiveDate', label: 'Effective Date', sortable: true, type: 'date' },
    { fieldName: 'brokerName', label: 'Broker', sortable: true, type: 'text' }
];

const FILTER_ALL = 'All';
const FILTER_BOUND = 'Bound';
const FILTER_NEW = 'New';
const FILTER_REVIEW = 'In Review';

const SORT_ASC = 'asc';
const SORT_ASC_MULTIPLIER = 1;
const SORT_DESC_MULTIPLIER = -1;

export default class InsurancePipelineDashboard extends LightningElement {
    @track submissions = [];
    @track filteredSubmissions = [];
    @track isLoading = true;
    @track hasError = false;
    @track errorMessage = '';
    @track activeFilter = FILTER_ALL;
    @track sortedBy = 'effectiveDate';
    @track sortedDirection = 'asc';
    @track columns = COLUMNS;

    get totalCount() {
        return this.submissions.length;
    }

    get newCount() {
        return this.submissions.filter((submission) => submission.status === FILTER_NEW).length;
    }

    get reviewCount() {
        return this.submissions.filter((submission) => submission.status === FILTER_REVIEW).length;
    }

    get boundCount() {
        return this.submissions.filter((submission) => submission.status === FILTER_BOUND).length;
    }

    get isEmpty() {
        return this.filteredSubmissions.length === 0;
    }

    get allVariant() {
        if (this.activeFilter === FILTER_ALL) {
            return 'brand';
        }
        return 'neutral';
    }

    get newVariant() {
        if (this.activeFilter === FILTER_NEW) {
            return 'brand';
        }
        return 'neutral';
    }

    get reviewVariant() {
        if (this.activeFilter === FILTER_REVIEW) {
            return 'brand';
        }
        return 'neutral';
    }

    get boundVariant() {
        if (this.activeFilter === FILTER_BOUND) {
            return 'brand';
        }
        return 'neutral';
    }

    @wire(getSubmissions)
    wiredSubmissions({ error, data }) {
        if (data) {
            this.submissions = data.map((item) => ({
                accountName: item.Account_Name__c,
                brokerName: item.Broker_Name__c,
                effectiveDate: item.Effective_Date__c,
                id: item.Id,
                lineOfBusiness: item.Line_of_Business__c,
                premium: item.Total_Premium__c,
                status: item.Status__c,
                submissionNumber: item.Submission_Number__c
            }));
            this.filteredSubmissions = this.submissions.slice();
            this.hasError = false;
        } else if (error) {
            this.hasError = true;
            this.errorMessage = error.body ? error.body.message : 'Unknown error loading submissions.';
            this.dispatchEvent(
                new ShowToastEvent({
                    message: this.errorMessage,
                    title: 'Error Loading Submissions',
                    variant: 'error'
                })
            );
        }
        this.isLoading = false;
    }

    handleFilterAll() {
        this.activeFilter = FILTER_ALL;
        this.filteredSubmissions = this.submissions.slice();
    }

    handleFilterNew() {
        this.activeFilter = FILTER_NEW;
        this.applyFilter(FILTER_NEW);
    }

    handleFilterReview() {
        this.activeFilter = FILTER_REVIEW;
        this.applyFilter(FILTER_REVIEW);
    }

    handleFilterBound() {
        this.activeFilter = FILTER_BOUND;
        this.applyFilter(FILTER_BOUND);
    }

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;
        this.filteredSubmissions = this.sortData(this.filteredSubmissions, fieldName, sortDirection);
    }

    /** @param {string} filterValue - Status value to filter by */
    applyFilter(filterValue) {
        this.filteredSubmissions = this.submissions.filter((item) => item.status === filterValue);
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
