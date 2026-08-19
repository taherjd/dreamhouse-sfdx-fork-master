import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getEndorsements from '@salesforce/apex/PolicyEndorsementController.getEndorsements';

const PAGE_SIZE = 10;
const STATUS_APPROVED = 'Approved';
const STATUS_PENDING = 'Pending';
const STATUS_REJECTED = 'Rejected';

export default class PolicyEndorsements extends LightningElement {
    @track endorsements = [];
    @track searchTerm = '';
    @track isLoading = true;
    @track hasError = false;
    @track errorMessage = '';
    @track visibleCount = PAGE_SIZE;

    get pendingCount() {
        return this.endorsements.filter((endorsement) => endorsement.status === STATUS_PENDING).length;
    }

    get approvedCount() {
        return this.endorsements.filter((endorsement) => endorsement.status === STATUS_APPROVED).length;
    }

    get rejectedCount() {
        return this.endorsements.filter((endorsement) => endorsement.status === STATUS_REJECTED).length;
    }

    get filteredEndorsements() {
        const term = this.searchTerm.toLowerCase();
        if (!term) {
            return this.endorsements;
        }
        return this.endorsements.filter((endorsement) => (
            (endorsement.policyNumber && endorsement.policyNumber.toLowerCase().includes(term)) ||
            (endorsement.accountName && endorsement.accountName.toLowerCase().includes(term))
        ));
    }

    get visibleEndorsements() {
        return this.filteredEndorsements.slice(0, this.visibleCount).map((endorsement) => {
            let badgeClass = 'badge-rejected';
            if (endorsement.status === STATUS_PENDING) {
                badgeClass = 'badge-pending';
            } else if (endorsement.status === STATUS_APPROVED) {
                badgeClass = 'badge-approved';
            }
            return Object.assign({}, endorsement, {
                badgeClass,
                rowClass: `endorsement-row slds-p-around_small slds-m-bottom_xx-small ${endorsement.statusClass}`
            });
        });
    }

    get hasEndorsements() {
        return this.visibleEndorsements.length > 0;
    }

    get hasMore() {
        return this.filteredEndorsements.length > this.visibleCount;
    }

    @wire(getEndorsements)
    wiredEndorsements({ error, data }) {
        if (data) {
            this.endorsements = data.map((item) => {
                let statusClass = 'row-rejected';
                if (item.Status__c === STATUS_PENDING) {
                    statusClass = 'row-pending';
                } else if (item.Status__c === STATUS_APPROVED) {
                    statusClass = 'row-approved';
                }
                return {
                    accountName: item.Account_Name__c,
                    endorsementType: item.Endorsement_Type__c,
                    id: item.Id,
                    policyNumber: item.Policy_Number__c,
                    premiumChange: item.Premium_Change__c,
                    requestedDate: item.Requested_Date__c,
                    status: item.Status__c,
                    statusClass
                };
            });
            this.hasError = false;
        } else if (error) {
            this.hasError = true;
            this.errorMessage = error.body ? error.body.message : 'Unknown error loading endorsements.';
            this.dispatchEvent(
                new ShowToastEvent({
                    message: this.errorMessage,
                    title: 'Error Loading Endorsements',
                    variant: 'error'
                })
            );
        }
        this.isLoading = false;
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
        this.visibleCount = PAGE_SIZE;
    }

    handleLoadMore() {
        this.visibleCount += PAGE_SIZE;
    }
}
