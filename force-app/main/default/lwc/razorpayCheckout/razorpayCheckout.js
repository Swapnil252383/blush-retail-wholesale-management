import { LightningElement, api } from 'lwc';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';


export default class RazorpayCheckout extends LightningElement {

    @api recordId;


    // ================================================
    // OPEN VISUALFORCE CHECKOUT
    // ================================================

    handlePay() {

        if (!this.recordId) {

            this.showToast(
                'Order Missing',
                'Open a saved Blush Order before starting payment.',
                'error'
            );

            return;
        }


        const checkoutUrl =
            '/apex/RazorpayCheckoutPage?orderId=' +
            encodeURIComponent(this.recordId);


        // Open directly during the button click to reduce
        // the chance of the browser blocking the new tab.
        const checkoutWindow = window.open(
            checkoutUrl,
            '_blank'
        );


        if (!checkoutWindow) {

            this.showToast(
                'Popup Blocked',
                'Allow popups for Salesforce and click Pay with Razorpay again.',
                'warning'
            );
        }
    }


    // ================================================
    // TOAST NOTIFICATIONS
    // ================================================

    showToast(title, message, variant) {

        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

}