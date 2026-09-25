import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPulse from '@salesforce/apex/RLM_PartnerAgreements.getPulse';

const currencyFmt = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    maximumFractionDigits: 0
});

export default class RlmPartnerPulse extends NavigationMixin(LightningElement) {
    errorMessage;
    loaded = false;
    accountName = 'Your account';
    kpis = [];
    insights = [];
    orderRows = [];
    agreementRows = [];
    quoteRows = [];
    utilizationPct = 0;

    @wire(getPulse)
    wiredPulse({ data, error }) {
        this.loaded = true;
        if (error) {
            this.errorMessage = this.reduceError(error);
            return;
        }
        this.errorMessage = undefined;
        if (!data) {
            return;
        }
        this.accountName = data.accountName || 'Your account';
        const contracted = data.contractedAmount || 0;
        const actual = data.actualAmount || 0;
        this.utilizationPct = contracted > 0
            ? Math.round((actual / contracted) * 100)
            : 0;

        this.kpis = [
            {
                key: 'ytd',
                label: 'YTD orders',
                value: this.formatMoney(data.ytdOrderAmount),
                hint: String(data.ytdOrderCount || 0) + ' this year'
            },
            {
                key: 'drawdown',
                label: 'Agreement drawdown',
                value: String(this.utilizationPct) + '%',
                hint: this.formatMoney(actual) + ' of ' + this.formatMoney(contracted)
            },
            {
                key: 'agreements',
                label: 'Agreements',
                value: String(data.activeAgreementCount || 0),
                hint: 'Activated run-rate contracts'
            },
            {
                key: 'quotes',
                label: 'Open pricing requests',
                value: String(data.openQuoteCount || 0),
                hint: 'Waiting on the seller'
            }
        ];

        this.insights = this.buildInsights(data);
        this.orderRows = (data.recentOrders || []).map((row) => ({
            ...row,
            dateDisplay: this.formatDate(row.effectiveDate),
            amountDisplay: this.formatMoney(row.totalAmount)
        }));
        this.agreementRows = (data.agreements || []).map((row) => ({
            ...row,
            startDisplay: this.formatDate(row.startDate),
            contractedDisplay: this.formatMoney(row.totalAmount),
            actualDisplay: this.formatMoney(row.actualAmount)
        }));
        this.quoteRows = (data.openQuotes || []).map((row) => ({
            ...row,
            dateDisplay: this.formatDate(row.createdDate),
            amountDisplay: this.formatMoney(row.grandTotal),
            kind: row.partnerRequest ? 'Price concession' : 'Quote'
        }));
    }

    get hasAccount() {
        return this.loaded && !this.errorMessage && this.accountName
            && this.accountName !== 'Your account';
    }

    get showEmptyAccount() {
        return this.loaded && !this.errorMessage && !this.hasAccount;
    }

    get hasOrders() {
        return this.orderRows && this.orderRows.length > 0;
    }

    get hasAgreements() {
        return this.agreementRows && this.agreementRows.length > 0;
    }

    get hasQuotes() {
        return this.quoteRows && this.quoteRows.length > 0;
    }

    get hasInsights() {
        return this.insights && this.insights.length > 0;
    }

    get barStyle() {
        const width = Math.max(0, Math.min(this.utilizationPct, 100));
        return 'width:' + width + '%';
    }

    buildInsights(data) {
        const rows = [];
        const name = data.accountName || 'This account';
        rows.push({
            key: 'contracted',
            kicker: 'Contracted price',
            body: name + ' hardware run-rate last closed 10–14% off list (median 12%). That net is on the Sales Agreement — call off here, do not re-type the discount.'
        });
        if ((data.contractedAmount || 0) > 0 && this.utilizationPct < 40) {
            const posted = this.formatMoney(data.actualAmount);
            rows.push({
                key: 'behind',
                kicker: 'Drawdown',
                body: this.utilizationPct > 0
                    ? posted + ' is already posted against this run-rate. Keep calling off the same agreement — do not start a new quote for contracted SKUs.'
                    : 'Call-off is still early against the planned agreement amount. Place a call-off order on My agreements to post actuals to the same contract.'
            });
        } else if (this.utilizationPct >= 80) {
            rows.push({
                key: 'hot',
                kicker: 'Drawdown',
                body: 'This agreement is mostly drawn. Flag a replenishment or a new run-rate quote before the partner goes off-contract.'
            });
        }
        if ((data.openQuoteCount || 0) > 0) {
            rows.push({
                key: 'pc',
                kicker: 'Exceptions',
                body: 'Open pricing requests are off-agreement SKUs (software, combined kits). Same Quote object the seller approves — not a one-way partner tool.'
            });
        }
        return rows;
    }

    openOrder(event) {
        this.openRecord(event.currentTarget.dataset.id, 'Order');
    }

    openAgreement(event) {
        this.openRecord(event.currentTarget.dataset.id, 'SalesAgreement');
    }

    openQuote(event) {
        this.openRecord(event.currentTarget.dataset.id, 'Quote');
    }

    openRecord(recordId, objectApiName) {
        if (!recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                objectApiName,
                actionName: 'view'
            }
        });
    }

    goAgreements() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'SalesAgreement',
                actionName: 'list'
            }
        });
    }

    goQuotes() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Quote',
                actionName: 'list'
            },
            state: {
                c__start: '1'
            }
        });
    }

    formatMoney(value) {
        if (value == null) {
            return '$0';
        }
        return currencyFmt.format(value);
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
        return error.message || 'Unable to load account pulse.';
    }
}
