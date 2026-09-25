import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getCallOffLines from '@salesforce/apex/RLM_PartnerAgreements.getCallOffLines';
import createCallOff from '@salesforce/apex/RLM_PartnerAgreements.createCallOff';

const currencyFmt = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD'
});

export default class RlmPartnerCallOff extends NavigationMixin(LightningElement) {
    @api recordId;
    showWizard = false;
    step = 'date';
    orderDate;
    groups = [];
    orderId;
    errorMessage;
    isBusy = false;
    loadedLines = false;
    dialogFocused = false;

    get isDisabled() {
        return !this.recordId;
    }

    get isDateStep() {
        return this.step === 'date';
    }

    get isProductStep() {
        return this.step === 'products';
    }

    get isDoneStep() {
        return this.step === 'done';
    }

    get hasGroups() {
        return this.groups && this.groups.length > 0;
    }

    get showEmptyLines() {
        return this.loadedLines && !this.hasGroups;
    }

    get selectedGroups() {
        return (this.groups || []).filter((group) => group.selected);
    }

    get allSelected() {
        return this.hasGroups && this.groups.every((group) => group.selected);
    }

    get displayRows() {
        const rows = [];
        (this.groups || []).forEach((group) => {
            const qty = this.parseQty(group.quantity);
            (group.lines || []).forEach((line, index) => {
                const ratio = Number(line.childRatio) || 1;
                const isChild = group.isKit && !line.isParent;
                rows.push({
                    key: line.id,
                    groupKey: group.key,
                    selected: group.selected,
                    isChild: isChild,
                    showCheckbox: index === 0,
                    rowClass: isChild ? 'kit-child' : group.isKit ? 'kit-parent' : '',
                    productName: line.productName,
                    kitHint: this.lineHint(group, isChild, index),
                    periodDisplay: index === 0 ? group.periodDisplay : '',
                    showQtyInput: index === 0,
                    quantity: group.quantity,
                    maxQuantity: group.maxQuantity,
                    qtyDisplay: Number.isFinite(qty) ? String(qty * ratio) : '',
                    priceDisplay: this.formatMoney(line.salesPrice)
                });
            });
        });
        return rows;
    }

    get createDisabled() {
        if (this.isBusy || this.selectedGroups.length === 0) {
            return true;
        }
        return this.selectedGroups.some((group) => {
            const qty = this.parseQty(group.quantity);
            return !Number.isFinite(qty) || qty < 1 || qty > group.maxQuantity;
        });
    }

    openWizard() {
        if (!this.recordId) {
            return;
        }
        const now = new Date();
        this.orderDate = [
            now.getFullYear(),
            String(now.getMonth() + 1).padStart(2, '0'),
            String(now.getDate()).padStart(2, '0')
        ].join('-');
        this.step = 'date';
        this.groups = [];
        this.orderId = undefined;
        this.errorMessage = undefined;
        this.isBusy = false;
        this.loadedLines = false;
        this.dialogFocused = false;
        this.showWizard = true;
    }

    closeWizard() {
        if (this.isBusy) {
            return;
        }
        this.showWizard = false;
    }

    handleBackdrop() {
        this.closeWizard();
    }

    handleKeydown(event) {
        if (event.key === 'Escape') {
            event.stopPropagation();
            this.closeWizard();
        }
    }

    handleDateChange(event) {
        this.orderDate = event.target.value;
    }

    backToDate() {
        this.step = 'date';
        this.errorMessage = undefined;
    }

    loadProducts() {
        if (!this.orderDate) {
            this.errorMessage = 'Choose an order date.';
            return;
        }
        this.isBusy = true;
        this.errorMessage = undefined;
        getCallOffLines({
            salesAgreementId: this.recordId,
            orderDate: this.orderDate
        })
            .then((data) => {
                this.groups = (data || []).map((group) => this.decorateGroup(group, true));
                this.loadedLines = true;
                this.step = 'products';
            })
            .catch((error) => {
                this.errorMessage = this.reduceError(error);
            })
            .finally(() => {
                this.isBusy = false;
            });
    }

    toggleAll(event) {
        const selected = event.target.checked;
        this.groups = this.groups.map((group) => ({ ...group, selected: selected }));
    }

    toggleGroup(event) {
        const groupKey = event.target.dataset.groupKey;
        const selected = event.target.checked;
        this.groups = this.groups.map((group) =>
            group.key === groupKey ? { ...group, selected: selected } : group
        );
    }

    handleQtyChange(event) {
        const groupKey = event.target.dataset.groupKey;
        const quantity = event.target.value;
        this.groups = this.groups.map((group) =>
            group.key === groupKey ? { ...group, quantity: quantity } : group
        );
    }

    createOrder() {
        const selections = [];
        for (const group of this.selectedGroups) {
            const qty = this.parseQty(group.quantity);
            if (!Number.isFinite(qty) || qty < 1) {
                this.errorMessage = 'Enter a quantity of 1 or more.';
                return;
            }
            if (qty > group.maxQuantity) {
                this.errorMessage =
                    'Quantity cannot exceed the planned amount for this period.';
                return;
            }
            (group.lines || []).forEach((line) => {
                const ratio = Number(line.childRatio) || 1;
                selections.push({
                    scheduleId: line.id,
                    quantity: qty * ratio
                });
            });
        }
        if (selections.length === 0) {
            this.errorMessage = 'Select at least one product.';
            return;
        }
        this.isBusy = true;
        this.errorMessage = undefined;
        createCallOff({
            salesAgreementId: this.recordId,
            orderDate: this.orderDate,
            selections: selections
        })
            .then((orderId) => {
                this.orderId = orderId;
                this.step = 'done';
                this.dispatchEvent(
                    new CustomEvent('calloffcreated', {
                        detail: { orderId: orderId }
                    })
                );
            })
            .catch((error) => {
                this.errorMessage = this.reduceError(error);
            })
            .finally(() => {
                this.isBusy = false;
            });
    }

    openOrder() {
        if (!this.orderId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.orderId,
                objectApiName: 'Order',
                actionName: 'view'
            }
        });
    }

    renderedCallback() {
        if (!this.showWizard) {
            this.dialogFocused = false;
            return;
        }
        if (this.dialogFocused) {
            return;
        }
        const dialog = this.template.querySelector('.dialog');
        if (dialog) {
            dialog.focus();
            this.dialogFocused = true;
        }
    }

    decorateGroup(group, selected) {
        const defaultQty = Number(group.defaultQuantity);
        const maxQuantity = Number.isFinite(defaultQty) && defaultQty > 0 ? defaultQty : 1;
        return {
            ...group,
            selected: selected,
            quantity: String(maxQuantity),
            maxQuantity: maxQuantity,
            periodDisplay: this.formatPeriod(group.startDate, group.endDate),
            lines: group.lines || []
        };
    }

    lineHint(group, isChild, index) {
        if (group.isKit && index === 0) {
            return 'Hardware kit — quantity applies to included SKUs';
        }
        if (isChild) {
            return 'Included in kit';
        }
        return '';
    }

    parseQty(value) {
        const qty = Number(value);
        return Number.isFinite(qty) ? qty : NaN;
    }

    formatMoney(value) {
        if (value == null) {
            return '';
        }
        return currencyFmt.format(value);
    }

    formatPeriod(startDate, endDate) {
        const start = this.formatDate(startDate);
        const end = this.formatDate(endDate);
        if (start && end) {
            return start + ' – ' + end;
        }
        return start || end || '';
    }

    formatDate(value) {
        if (!value) {
            return '';
        }
        try {
            return new Intl.DateTimeFormat('en-US', {
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
        return error.message || 'Unable to create the order.';
    }
}
