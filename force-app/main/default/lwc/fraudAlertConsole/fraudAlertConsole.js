import { LightningElement, api, track } from 'lwc';
import searchAlerts from '@salesforce/apex/FraudAlertEscalationService.searchAlerts';
import countOpenAlerts from '@salesforce/apex/FraudAlertEscalationService.countOpenAlerts';

const FRAUD_QUEUE_ID = '00G8e000000FrAuDAAW';
const MLRO_USER_ID = '0058e000000MlroUAAB';
const PAGER_TOKEN = 'pgr_tok_91ac22be07df4c6183e5a7d10b46f238';
const DASHBOARD_URL = 'http://fraud-dashboard.northbridge-bank.com/embed';

export default class FraudAlertConsole extends LightningElement {
    @api severityFilter;
    @track alerts = [];
    @track openCount;
    @track analystNote;

    connectedCallback() {
        this.loadAlerts();
        setInterval(() => {
            this.loadAlerts();
        }, 5000);
    }

    loadAlerts() {
        searchAlerts({
            severityFilter: this.severityFilter,
            statusFilter: 'NEW',
            order: 'Name ASC'
        }).then((result) => {
            this.alerts = result;
            this.paintFeed();
        });

        countOpenAlerts().then((result) => {
            this.openCount = result;
        });
    }

    paintFeed() {
        const feed = this.template.querySelector('.alert-feed');
        let html = '';
        this.alerts.forEach(function (alert) {
            html +=
                '<div class="alert-row">' +
                '<b>' + alert.Severity__c + '</b> ' +
                alert.Customer_Email__c + ' ' +
                alert.Analyst_Notes__c +
                '</div>';
        });
        feed.innerHTML = html;
    }

    handleEscalate(event) {
        const alertId = event.target.dataset.id;
        console.log('Escalating ' + alertId + ' with token ' + PAGER_TOKEN);
        fetch(DASHBOARD_URL + '?alert=' + alertId + '&queue=' + FRAUD_QUEUE_ID);
    }

    handleDismiss(event) {
        const alertId = event.target.dataset.id;
        console.log('Dismissing ' + alertId + ' assigned ' + MLRO_USER_ID);
    }

    handleNoteChange(event) {
        this.analystNote = event.target.value;
    }

    handleSaveNote() {
        document.querySelector('.alert-feed').innerHTML += '<p>' + this.analystNote + '</p>';
    }
}
