import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from 'lightning/platformResourceLoader';
import discoveryBrand from '@salesforce/resourceUrl/RLM_PartnerDiscovery';
import getQuoteSummary from '@salesforce/apex/RLM_PartnerAgreements.getQuoteSummary';
import requestPriceConcession from '@salesforce/apex/RLM_PartnerAgreements.requestPriceConcession';
import updateParentQuantity from '@salesforce/apex/RLM_PartnerAgreements.updateParentQuantity';

const currencyFmt = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD'
});

export default class RlmPartnerQuote extends NavigationMixin(LightningElement) {
    @api recordId;

    summary;
    errorMessage;
    loaded = false;
    wiredResult;
    selectedCatalog;
    showCatalog = false;
    catalogDialogFocused = false;
    catalogSession = 0;
    discoveryStyled = false;
    qtySaving = false;
    showConcession = false;
    justification = '';
    submitting = false;
    dialogFocused = false;
    concessionDone = false;
    concessionError;

    @wire(getQuoteSummary, { recordId: '$recordId' })
    wiredSummary(result) {
        this.wiredResult = result;
        this.loaded = true;
        if (result.error) {
            this.summary = undefined;
            this.errorMessage = this.reduceError(result.error);
            return;
        }
        this.errorMessage = undefined;
        this.summary = result.data;
        if (result.data && result.data.justification) {
            this.justification = result.data.justification;
        }
        if (result.data && result.data.partnerRequest && result.data.justification) {
            this.concessionDone = true;
        }
        if (!this.selectedCatalog && result.data && result.data.catalogs && result.data.catalogs.length) {
            const hardware = result.data.catalogs.find((catalog) => catalog.name === 'Hardware');
            this.selectedCatalog = (hardware || result.data.catalogs[0]).name;
        }
    }

    get hasQuote() {
        return Boolean(this.summary && this.summary.id);
    }

    get showLoading() {
        return !this.loaded && !this.errorMessage;
    }

    get catalogs() {
        return (this.summary && this.summary.catalogs) || [];
    }

    get groups() {
        return ((this.summary && this.summary.groups) || []).map((group) => ({
            ...group,
            netDisplay: this.formatMoney(group.netAmount),
            lines: (group.lines || []).map((line) => ({
                ...line,
                qtyDisplay: line.quantity == null ? '' : String(line.quantity),
                listDisplay: this.formatMoney(line.listPrice),
                netDisplay: this.formatMoney(line.netAmount),
                rowClass: line.isParent ? 'line parent' : 'line child'
            }))
        }));
    }

    get hasLines() {
        return this.groups.some((group) => group.lines && group.lines.length);
    }

    get accountName() {
        return (this.summary && this.summary.accountName) || 'Your account';
    }

    get solutionName() {
        return (this.summary && this.summary.solutionName) || 'New solution';
    }

    get statusLabel() {
        return (this.summary && this.summary.status) || 'Draft';
    }

    get statusClass() {
        return this.statusLabel === 'Draft' ? 'status status-draft' : 'status';
    }

    get quoteNumber() {
        return (this.summary && this.summary.quoteNumber) || '—';
    }

    get createdDisplay() {
        return this.formatDate(this.summary && this.summary.createdDate);
    }

    get totalDisplay() {
        return this.formatMoney(this.summary && this.summary.grandTotal);
    }

    get quoteTitle() {
        return (this.summary && this.summary.name) || 'Configure & Quote';
    }

    get browseDisabled() {
        return !this.recordId || !this.selectedCatalog;
    }

    get flowInputVariables() {
        const inputs = [
            { name: 'recordId', type: 'String', value: this.recordId },
            { name: 'objectApiName', type: 'String', value: 'Quote' }
        ];
        const selected = (this.catalogs || []).find((catalog) => catalog.name === this.selectedCatalog);
        if (selected && selected.id) {
            inputs.push({ name: 'defaultCatalog', type: 'String', value: selected.id });
        }
        return inputs;
    }

    get sendLabel() {
        return this.submitting ? 'Sending…' : 'Send request';
    }

    get catalogCards() {
        const selected = this.selectedCatalog;
        return this.catalogs.map((catalog) => ({
            ...catalog,
            key: catalog.id || catalog.name,
            cardClass: catalog.name === selected ? 'catalog selected' : 'catalog'
        }));
    }

    selectCatalog(event) {
        this.selectedCatalog = event.currentTarget.dataset.name;
    }

    browseCatalogs() {
        if (this.browseDisabled) {
            return;
        }
        this.catalogSession += 1;
        this.showCatalog = false;
        this.catalogDialogFocused = false;
        Promise.resolve().then(() => {
            this.showCatalog = true;
        });
    }

    handleParentQty(event) {
        const lineId = event.currentTarget.dataset.id;
        const quantity = Number(event.target.value);
        if (!lineId || !Number.isFinite(quantity) || quantity < 1) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Quantity',
                message: 'Enter a quantity of 1 or more on the kit header.',
                variant: 'error'
            }));
            return;
        }
        this.qtySaving = true;
        updateParentQuantity({
            recordId: this.recordId,
            lineId: lineId,
            quantity: quantity
        })
            .then((result) => {
                if (!result || result.isSuccess === false) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Quantity',
                        message: (result && result.errorMessage) || 'Could not update quantity.',
                        variant: 'error'
                    }));
                    return;
                }
                this.refresh();
            })
            .catch((error) => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Quantity',
                    message: this.reduceError(error),
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.qtySaving = false;
            });
    }

    closeCatalog() {
        this.showCatalog = false;
        this.refresh();
    }

    handleCatalogKeydown(event) {
        if (event.key === 'Escape') {
            event.stopPropagation();
            this.closeCatalog();
        }
    }

    handleFlowStatus(event) {
        const status = event.detail && event.detail.status;
        if (status === 'FINISHED' || status === 'FINISHED_SCREEN') {
            this.closeCatalog();
        }
    }

    saveQuote() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Quote saved',
            message: 'Products on this quote are already on the record. Refresh if you just added a kit.',
            variant: 'success'
        }));
        this.refresh();
    }

    checkout() {
        if (!this.recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: {
                apiName: 'Quote.CreateOrder'
            },
            state: {
                recordId: this.recordId,
                objectApiName: 'Quote'
            }
        });
    }

    openConcession() {
        this.showConcession = true;
        this.dialogFocused = false;
        this.concessionError = null;
        if (!this.justification) {
            this.justification = '';
        }
    }

    closeConcession() {
        if (this.submitting) {
            return;
        }
        this.showConcession = false;
    }

    handleBackdrop() {
        this.closeConcession();
    }

    handleKeydown(event) {
        if (event.key === 'Escape') {
            event.stopPropagation();
            this.closeConcession();
        }
    }

    handleJustification(event) {
        this.justification = event.target.value;
        this.concessionError = null;
    }

    readJustification() {
        const box = this.template.querySelector('[data-id="pc-justification"]');
        if (box && typeof box.value === 'string') {
            this.justification = box.value;
        }
        return (this.justification || '').trim();
    }

    submitConcession(event) {
        if (event) {
            event.preventDefault();
            event.stopPropagation();
        }
        if (this.submitting) {
            return;
        }
        const note = this.readJustification();
        if (note.length < 8) {
            this.concessionError = 'Add a short note for deal desk — what you need and why.';
            return;
        }
        this.concessionError = null;
        this.submitting = true;
        requestPriceConcession({
            recordId: this.recordId,
            justification: note
        })
            .then((result) => {
                if (!result || result.isSuccess === false) {
                    this.concessionError = (result && result.errorMessage) || 'Could not submit the request.';
                    return;
                }
                this.concessionDone = true;
                this.showConcession = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Request sent',
                    message: result.message || 'deal desk has your request.',
                    variant: 'success'
                }));
                this.refresh();
            })
            .catch((error) => {
                this.concessionError = this.reduceError(error);
            })
            .finally(() => {
                this.submitting = false;
            });
    }

    refresh() {
        if (this.wiredResult) {
            refreshApex(this.wiredResult);
        }
    }

    renderedCallback() {
        if (!this.discoveryStyled) {
            this.discoveryStyled = true;
            loadStyle(this, discoveryBrand).catch(() => {
                this.discoveryStyled = false;
            });
        }
        if (this.showCatalog && !this.catalogDialogFocused) {
            const catalogDialog = this.template.querySelector('.catalog-dialog');
            if (catalogDialog) {
                catalogDialog.focus();
                this.catalogDialogFocused = true;
            }
        }
        if (!this.showCatalog) {
            this.catalogDialogFocused = false;
        }
        if (!this.showConcession) {
            this.dialogFocused = false;
            return;
        }
        if (this.dialogFocused) {
            return;
        }
        const dialog = this.template.querySelector('.dialog:not(.catalog-dialog)');
        if (dialog) {
            dialog.focus();
            this.dialogFocused = true;
        }
    }

    formatMoney(value) {
        if (value == null) {
            return '$0.00';
        }
        return currencyFmt.format(value);
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
        return error.message || 'Unable to load this quote.';
    }
}
