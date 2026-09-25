import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import startConfigureQuote from '@salesforce/apex/RLM_PartnerStartQuote.startConfigureQuote';

export default class RlmPartnerStartQuote extends NavigationMixin(LightningElement) {
    @api autoStart = false;

    starting = false;
    errorMessage;
    startedFromUrl = false;

    connectedCallback() {
        this.maybeAutoStart();
    }

    @wire(CurrentPageReference)
    handlePageRef(pageRef) {
        this.pageRef = pageRef;
        this.maybeAutoStart();
    }

    maybeAutoStart() {
        if (this.startedFromUrl || this.starting) {
            return;
        }
        const state = (this.pageRef && this.pageRef.state) || {};
        const stateWantsStart = state.c__start === '1' || state.start === '1';
        if (this.autoStart === true || stateWantsStart || this.urlWantsStart()) {
            this.startedFromUrl = true;
            this.startQuote();
        }
    }

    urlWantsStart() {
        try {
            const href = window.location.href || '';
            const search = window.location.search || '';
            const hash = window.location.hash || '';
            const params = new URLSearchParams(search);
            const hashParams = new URLSearchParams(hash.split('?')[1] || '');
            return (
                params.get('c__start') === '1'
                || params.get('start') === '1'
                || hashParams.get('c__start') === '1'
                || hashParams.get('start') === '1'
                || href.includes('c__start=1')
                || href.includes('start=1')
            );
        } catch (e) {
            return false;
        }
    }

    startQuote() {
        if (this.starting) {
            return;
        }
        this.starting = true;
        this.errorMessage = undefined;
        startConfigureQuote({ quoteName: 'Partner quote' })
            .then((result) => {
                if (!result || result.isSuccess === false || !result.quoteId) {
                    this.errorMessage = (result && result.errorMessage)
                        || 'Could not start the quote.';
                    return;
                }
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: result.quoteId,
                        objectApiName: 'Quote',
                        actionName: 'view'
                    }
                });
            })
            .catch((error) => {
                this.errorMessage = this.reduceError(error);
            })
            .finally(() => {
                this.starting = false;
            });
    }

    reduceError(error) {
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (error.body && error.body.message) {
            return error.body.message;
        }
        return error.message || 'Could not start the quote.';
    }
}
