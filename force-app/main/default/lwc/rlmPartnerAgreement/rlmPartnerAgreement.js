import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getAgreementDetail from '@salesforce/apex/RLM_PartnerAgreements.getAgreementDetail';

const currencyFmt = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD'
});

export default class RlmPartnerAgreement extends NavigationMixin(LightningElement) {
    @api recordId;

    agreement;
    priceRows = [];
    orderRows = [];
    errorMessage;
    loaded = false;
    wiredDetailResult;

    @wire(getAgreementDetail, { recordId: '$recordId' })
    wiredDetail(result) {
        this.wiredDetailResult = result;
        const data = result.data;
        const error = result.error;
        this.loaded = true;
        if (data && data.agreement) {
            this.agreement = data.agreement;
            this.orderRows = (data.orders || []).map((row) => ({
                ...row,
                dateDisplay: this.formatDate(row.effectiveDate),
                amountDisplay: this.formatMoney(row.totalAmount),
                statusClass: row.status === 'Activated' ? 'status status-on' : 'status'
            }));
            this.priceRows = (data.prices || []).map((row) => {
                const planned = Number(row.plannedQuantity) || 0;
                const actual = Number(row.actualQuantity) || 0;
                const remaining = Math.max(planned - actual, 0);
                const pct = planned > 0 ? Math.min(100, Math.round((actual / planned) * 100)) : 0;
                return {
                    ...row,
                    productDisplay: row.productName || row.name || '',
                    skuDisplay: row.sku || row.name || '',
                    listDisplay: this.formatMoney(row.listPrice),
                    netDisplay: this.formatMoney(row.salesPrice),
                    discountDisplay: this.formatPercent(row.discountPercentage),
                    qtyDisplay: this.formatQty(row.plannedQuantity),
                    actualDisplay: this.formatQty(row.actualQuantity),
                    remainingDisplay: this.formatQty(remaining),
                    meterStyle: 'width:' + String(pct) + '%'
                };
            });
            this.errorMessage = undefined;
        } else if (error) {
            this.agreement = undefined;
            this.priceRows = [];
            this.orderRows = [];
            this.errorMessage = this.reduceError(error);
        } else {
            this.agreement = undefined;
            this.priceRows = [];
            this.orderRows = [];
            this.errorMessage = undefined;
        }
    }

    handleCalloffCreated() {
        if (this.wiredDetailResult) {
            refreshApex(this.wiredDetailResult);
        }
    }

    get hasAgreement() {
        return Boolean(this.agreement);
    }

    get hasPrices() {
        return this.priceRows && this.priceRows.length > 0;
    }

    get hasOrders() {
        return this.orderRows && this.orderRows.length > 0;
    }

    get showLoading() {
        return !this.loaded && !this.errorMessage;
    }

    get showMissing() {
        return this.loaded && !this.errorMessage && !this.hasAgreement;
    }

    get showPriceEmpty() {
        return this.hasAgreement && !this.hasPrices;
    }

    get isActivated() {
        return this.agreement && this.agreement.status === 'Activated';
    }

    get statusClass() {
        return this.isActivated ? 'status status-on' : 'status';
    }

    get startDisplay() {
        return this.formatDate(this.agreement && this.agreement.startDate);
    }

    get endDisplay() {
        return this.formatDate(this.agreement && this.agreement.endDate);
    }

    get amountDisplay() {
        return this.formatMoney(this.agreement && this.agreement.totalAmount);
    }

    get scheduleDisplay() {
        if (!this.agreement) {
            return '';
        }
        const freq = this.agreement.scheduleFrequency || '';
        const count = this.agreement.scheduleCount;
        if (count != null && freq) {
            return String(count) + ' × ' + freq;
        }
        return freq;
    }

    get lineCountDisplay() {
        return String(this.priceRows.length);
    }

    get actualsDisplay() {
        const planned = this.priceRows.reduce(
            (sum, row) => sum + (Number(row.plannedQuantity) || 0),
            0
        );
        const actual = this.priceRows.reduce(
            (sum, row) => sum + (Number(row.actualQuantity) || 0),
            0
        );
        return (
            this.formatQty(actual) +
            ' of ' +
            this.formatQty(planned) +
            ' · ' +
            this.formatMoney(this.agreement && this.agreement.actualAmount)
        );
    }

    openOrder(event) {
        const recordId = event.currentTarget.dataset.id;
        if (!recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Order',
                actionName: 'view'
            }
        });
    }

    formatQty(value) {
        if (value == null || value === '') {
            return '0';
        }
        return String(value);
    }

    formatMoney(value) {
        if (value == null) {
            return '—';
        }
        return currencyFmt.format(value);
    }

    formatPercent(value) {
        if (value == null) {
            return '—';
        }
        return String(value) + '%';
    }

    formatDate(value) {
        if (!value) {
            return '—';
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
        return error.message || 'Unable to load this agreement.';
    }
}
