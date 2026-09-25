import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getAgreements from '@salesforce/apex/RLM_PartnerAgreements.getAgreements';
import getContractedPrices from '@salesforce/apex/RLM_PartnerAgreements.getContractedPrices';

const currencyFmt = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD'
});

export default class RlmPartnerContractedPrices extends NavigationMixin(LightningElement) {
    errorMessage;
    agreementRows = [];
    priceRows = [];
    loadedAgreements = false;
    loadedPrices = false;

    @wire(getAgreements)
    wiredAgreements({ data, error }) {
        this.loadedAgreements = true;
        if (data) {
            this.agreementRows = data.map((row) => ({
                ...row,
                startDisplay: this.formatDate(row.startDate),
                amountDisplay: this.formatMoney(row.totalAmount)
            }));
            this.errorMessage = undefined;
        } else if (error) {
            this.agreementRows = [];
            this.errorMessage = this.reduceError(error);
        }
    }

    @wire(getContractedPrices)
    wiredPrices({ data, error }) {
        this.loadedPrices = true;
        if (data) {
            this.priceRows = data.map((row) => ({
                ...row,
                listDisplay: this.formatMoney(row.listPrice),
                netDisplay: this.formatMoney(row.salesPrice),
                discountDisplay: this.formatPercent(row.discountPercentage),
                qtyDisplay: row.plannedQuantity == null ? '' : String(row.plannedQuantity)
            }));
            if (!this.errorMessage) {
                this.errorMessage = undefined;
            }
        } else if (error) {
            this.priceRows = [];
            this.errorMessage = this.reduceError(error);
        }
    }

    get hasAgreements() {
        return this.agreementRows && this.agreementRows.length > 0;
    }

    get hasPrices() {
        return this.priceRows && this.priceRows.length > 0;
    }

    get showAgreementEmpty() {
        return this.loadedAgreements && !this.errorMessage && !this.hasAgreements;
    }

    get showPriceEmpty() {
        return this.loadedPrices && !this.errorMessage && !this.hasPrices;
    }

    openAgreement(event) {
        const recordId = event.currentTarget.dataset.id;
        if (!recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                objectApiName: 'SalesAgreement',
                actionName: 'view'
            }
        });
    }

    formatMoney(value) {
        if (value == null) {
            return '';
        }
        return currencyFmt.format(value);
    }

    formatPercent(value) {
        if (value == null) {
            return '';
        }
        return String(value) + '%';
    }

    formatDate(value) {
        if (!value) {
            return '';
        }
        try {
            return new Intl.DateTimeFormat('en-US', {
                year: 'numeric',
                month: 'short',
                day: 'numeric'
            }).format(new Date(value));
        } catch (e) {
            return String(value);
        }
    }

    reduceError(error) {
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (error.body && error.body.message) {
            return error.body.message;
        }
        return error.message || 'Unable to load agreements.';
    }
}
