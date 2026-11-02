import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import saveInvoicePdf from '@salesforce/apex/InvoiceController.saveInvoicePdf';

export default class GenerateInvoice extends NavigationMixin(LightningElement) {
    @api recordId;
    isSaving = false;

    handlePreview() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: `/apex/BlushInvoice?id=${this.recordId}` }
        });
    }

    async handleSave() {
        this.isSaving = true;
        try {
            const documentId = await saveInvoicePdf({ orderId: this.recordId });
            this.dispatchEvent(
                new ShowToastEvent({ title: 'Invoice saved', message: 'The invoice PDF was added to the order Files.', variant: 'success' })
            );
            this[NavigationMixin.Navigate]({
                type: 'standard__namedPage',
                attributes: { pageName: 'filePreview' },
                state: { selectedRecordId: documentId }
            });
            this.handleClose();
        } catch (error) {
            const message = error?.body?.message || error?.message || 'Unknown error';
            this.dispatchEvent(new ShowToastEvent({ title: 'Could not save invoice', message, variant: 'error' }));
        } finally {
            this.isSaving = false;
        }
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}