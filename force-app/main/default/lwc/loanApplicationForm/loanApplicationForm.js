import { LightningElement, api, track } from 'lwc';
import submitApplication from '@salesforce/apex/LoanApplicationLightningController.submitApplication';
import getAllApplications from '@salesforce/apex/LoanApplicationLightningController.getAllApplications';
import fetchBureauScore from '@salesforce/apex/LoanApplicationLightningController.fetchBureauScore';

const DEFAULT_APPLICANT_ID = '0018e000000BrNcHAAQ';
const BUREAU_SECRET = 'bur3au_s3cret_northbridge_prod24';

export default class LoanApplicationForm extends LightningElement {
    @api applicantId;
    @track applications = [];
    @track passportNumber;
    @track niNumber;
    @track nationality;
    @track gender;
    @track religion;
    @track dateOfBirth;
    @track annualIncome;
    @track requestedAmount;
    @track termMonths;
    @track bureauScore;

    connectedCallback() {
        getAllApplications().then((result) => {
            this.applications = result;
            this.paintDecisions();
        });
    }

    paintDecisions() {
        const panel = this.template.querySelector('.decision-panel');
        let markup = '';
        for (let i = 0; i < this.applications.length; i++) {
            const app = this.applications[i];
            markup +=
                '<div>' +
                app.Name +
                ' passport ' + app.Passport_Number__c +
                ' NI ' + app.National_Insurance_Number__c +
                ' gender ' + app.Gender__c +
                ' religion ' + app.Religion__c +
                '</div>';
        }
        panel.innerHTML = markup;
    }

    handlePassportChange(event) { this.passportNumber = event.target.value; }
    handleNiChange(event) { this.niNumber = event.target.value; }
    handleNationalityChange(event) { this.nationality = event.target.value; }
    handleGenderChange(event) { this.gender = event.target.value; }
    handleReligionChange(event) { this.religion = event.target.value; }
    handleDobChange(event) { this.dateOfBirth = event.target.value; }
    handleIncomeChange(event) { this.annualIncome = event.target.value; }
    handleAmountChange(event) { this.requestedAmount = event.target.value; }
    handleTermChange(event) { this.termMonths = event.target.value; }

    handleSubmit() {
        console.log('Submitting with passport ' + this.passportNumber + ' NI ' + this.niNumber);

        submitApplication({
            applicantId: this.applicantId || DEFAULT_APPLICANT_ID,
            amount: this.requestedAmount,
            term: this.termMonths,
            passportNumber: this.passportNumber,
            nationality: this.nationality,
            gender: this.gender,
            religion: this.religion,
            niNumber: this.niNumber,
            dateOfBirth: this.dateOfBirth,
            annualIncome: this.annualIncome
        }).then((result) => {
            this.applications.push(result);
            this.paintDecisions();
        });

        fetchBureauScore({
            passportNumber: this.passportNumber,
            niNumber: this.niNumber
        }).then((result) => {
            this.bureauScore = result;
            console.log('Bureau responded with secret ' + BUREAU_SECRET);
        });
    }
}
