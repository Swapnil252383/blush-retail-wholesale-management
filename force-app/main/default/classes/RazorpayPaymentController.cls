public with sharing class RazorpayPaymentController {

    private static final String API_ENDPOINT =
        'callout:Razorpay_API';


    // ==================================================
    // 1. CREATE A RAZORPAY ORDER
    // ==================================================

    @AuraEnabled
    public static Map<String, Object> createPaymentOrder(
        Id orderId
    ) {

        if (orderId == null) {
            throw new RazorpayPaymentException(
                'Select a saved Blush Order first.'
            );
        }

        Order blushOrder = [
            SELECT Id,
                   OrderNumber,
                   Net_Amount__c,
                   Payment_Status__c,
                   Payment_Mode__c,
                   Approval_Status__c,
                   Max_Discount_Percent__c
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];

        if (blushOrder.Payment_Status__c == 'Paid') {
            throw new RazorpayPaymentException(
                'This Order has already been paid.'
            );
        }

        // Block payments while discount approval is outstanding
        // or has been rejected.
        Set<String> blockedApprovalStatuses = new Set<String>{
            'Required',
            'Pending',
            'Rejected'
        };

        if (
            blockedApprovalStatuses.contains(
                blushOrder.Approval_Status__c
            )
        ) {
            throw new RazorpayPaymentException(
                'Complete the required discount approval before payment.'
            );
        }

        // A discount above 10% must have explicit approval.
        if (
            blushOrder.Max_Discount_Percent__c != null &&
            blushOrder.Max_Discount_Percent__c > 0.10 &&
            blushOrder.Approval_Status__c != 'Approved'
        ) {
            throw new RazorpayPaymentException(
                'A discount above 10% must be approved before payment.'
            );
        }

        if (
            blushOrder.Net_Amount__c == null ||
            blushOrder.Net_Amount__c <= 0
        ) {
            throw new RazorpayPaymentException(
                'The Order payable amount must be greater than zero.'
            );
        }

        Razorpay_Settings__mdt settings =
            getTestSettings();

        // INR amount must be converted to paise.
        Decimal amountPaiseDecimal =
            (blushOrder.Net_Amount__c * 100)
            .setScale(0, RoundingMode.HALF_UP);

        Integer amountPaise =
            amountPaiseDecimal.intValue();

        if (amountPaise <= 0) {
            throw new RazorpayPaymentException(
                'The calculated payment amount is invalid.'
            );
        }

        String receipt =
            'BL-' +
            blushOrder.OrderNumber +
            '-' +
            String.valueOf(DateTime.now().getTime());

        Map<String, Object> requestBody =
            new Map<String, Object>{
                'amount' => amountPaise,
                'currency' => 'INR',
                'receipt' => receipt,
                'notes' => new Map<String, Object>{
                    'salesforce_order_id' =>
                        String.valueOf(blushOrder.Id)
                }
            };

        // Complete the API callout before performing DML.
        Map<String, Object> razorpayOrder =
            sendRazorpayRequest(
                '/v1/orders',
                'POST',
                JSON.serialize(requestBody)
            );

        String razorpayOrderId =
            (String) razorpayOrder.get('id');

        if (String.isBlank(razorpayOrderId)) {
            throw new RazorpayPaymentException(
                'Razorpay did not return an Order ID.'
            );
        }

        // Create one Salesforce payment transaction attempt.
        Payment_Transaction__c paymentTransaction =
            new Payment_Transaction__c(
                Order__c = blushOrder.Id,
                Expected_Amount__c =
                    blushOrder.Net_Amount__c,
                Razorpay_Order_ID__c =
                    razorpayOrderId,
                Status__c = 'Created',
                Signature_Verified__c = false
            );

        insert paymentTransaction;

        // Never return the Key Secret to the browser.
        return new Map<String, Object>{
            'keyId' => settings.Key_ID__c,
            'razorpayOrderId' => razorpayOrderId,
            'paymentTransactionId' =>
                paymentTransaction.Id,
            'amountPaise' => amountPaise,
            'currency' => 'INR'
        };
    }


    // ==================================================
    // 2. VERIFY A RAZORPAY PAYMENT
    // ==================================================

    @AuraEnabled
    public static String verifyPayment(
        Id orderId,
        Id paymentTransactionId,
        String paymentId,
        String signature
    ) {

        if (
            orderId == null ||
            paymentTransactionId == null ||
            String.isBlank(paymentId) ||
            String.isBlank(signature)
        ) {
            throw new RazorpayPaymentException(
                'Required payment verification details are missing.'
            );
        }

        // Ensure this transaction belongs to the supplied Order.
        Payment_Transaction__c tx = [
            SELECT Id,
                   Order__c,
                   Expected_Amount__c,
                   Captured_Amount__c,
                   Razorpay_Order_ID__c,
                   Razorpay_Payment_ID__c,
                   Status__c,
                   Signature_Verified__c,
                   Verified_At__c,
                   Failure_Details__c
            FROM Payment_Transaction__c
            WHERE Id = :paymentTransactionId
              AND Order__c = :orderId
            LIMIT 1
        ];

        Order blushOrder = [
            SELECT Id,
                   Net_Amount__c,
                   Payment_Status__c,
                   Payment_Mode__c
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];

        // Handle a repeated successful callback.
        if (
            tx.Status__c == 'Captured' &&
            tx.Razorpay_Payment_ID__c == paymentId &&
            tx.Signature_Verified__c == true &&
            blushOrder.Payment_Status__c == 'Paid'
        ) {
            return 'This payment has already been verified.';
        }

        if (blushOrder.Payment_Status__c == 'Paid') {
            return 'This Order is already marked Paid.';
        }

        if (
            String.isBlank(tx.Razorpay_Order_ID__c) ||
            tx.Expected_Amount__c == null ||
            blushOrder.Net_Amount__c == null
        ) {
            throw new RazorpayPaymentException(
                'The saved payment details are incomplete.'
            );
        }

        Razorpay_Settings__mdt settings =
            getTestSettings();

        // Calculate the expected Checkout signature using the
        // server-stored Razorpay Order ID and test Key Secret.
        String signatureMessage =
            tx.Razorpay_Order_ID__c + '|' + paymentId;

        String expectedSignature =
            EncodingUtil.convertToHex(
                Crypto.generateMac(
                    'HmacSHA256',
                    Blob.valueOf(signatureMessage),
                    Blob.valueOf(settings.Key_Secret__c)
                )
            ).toLowerCase();

        if (
            !signaturesMatch(
                expectedSignature,
                signature
            )
        ) {
            tx.Status__c = 'Verification Failed';
            tx.Signature_Verified__c = false;
            tx.Failure_Details__c =
                'Checkout signature verification failed.';

            update tx;

            return
                'Payment signature verification failed. ' +
                'The Order remains Pending.';
        }

        // Independently retrieve the payment using Razorpay's API.
        String safePaymentId =
            EncodingUtil.urlEncode(paymentId, 'UTF-8');

        Map<String, Object> paymentResponse =
            sendRazorpayRequest(
                '/v1/payments/' + safePaymentId,
                'GET',
                null
            );

        String returnedOrderId =
            (String) paymentResponse.get('order_id');

        String returnedStatus =
            (String) paymentResponse.get('status');

        // "currency" is avoided as an Apex identifier.
        String paymentCurrency =
            (String) paymentResponse.get('currency');

        Decimal actualPaise;

        if (paymentResponse.get('amount') != null) {
            actualPaise = Decimal.valueOf(
                String.valueOf(
                    paymentResponse.get('amount')
                )
            );
        }

        Decimal expectedPaise =
            (tx.Expected_Amount__c * 100)
            .setScale(0, RoundingMode.HALF_UP);

        Decimal currentOrderPaise =
            (blushOrder.Net_Amount__c * 100)
            .setScale(0, RoundingMode.HALF_UP);

        Boolean matchingPayment =
            returnedOrderId == tx.Razorpay_Order_ID__c &&
            actualPaise != null &&
            actualPaise == expectedPaise &&
            expectedPaise == currentOrderPaise &&
            paymentCurrency == 'INR';

        Boolean isCaptured = false;

        if (paymentResponse.get('captured') != null) {
            isCaptured =
                (Boolean) paymentResponse.get('captured');
        }

        // A valid signature alone is not enough:
        // the payment must match the saved Order and amount.
        tx.Signature_Verified__c = true;
        tx.Razorpay_Payment_ID__c = paymentId;

        if (!matchingPayment) {
            tx.Status__c = 'Verification Failed';

            tx.Failure_Details__c =
                'Razorpay payment does not match the saved Order ID, amount, or currency.';

            update tx;

            return
                'Payment details do not match the expected Order. ' +
                'The Order remains Pending.';
        }

        // Authorized is not equivalent to captured.
        if (
            returnedStatus != 'captured' ||
            !isCaptured
        ) {
            tx.Status__c =
                returnedStatus == 'authorized'
                    ? 'Authorized'
                    : 'Failed';

            tx.Failure_Details__c =
                returnedStatus == 'authorized'
                    ? 'Payment is authorized but not captured.'
                    : 'Payment is not confirmed as captured.';

            update tx;

            return
                'Payment is not confirmed as captured. ' +
                'The Order remains Pending.';
        }

        // Only a confirmed captured payment updates the Order.
        tx.Status__c = 'Captured';

        tx.Captured_Amount__c =
            actualPaise.divide(100, 2);

        tx.Verified_At__c = System.now();
        tx.Failure_Details__c = null;

        blushOrder.Payment_Mode__c = 'Razorpay';
        blushOrder.Payment_Status__c = 'Paid';

        // Salesforce rolls back these updates together if one fails.
        update tx;
        update blushOrder;

        return
            'Payment verified successfully. Blush Order is Paid.';
    }


    // ==================================================
    // 3. LOAD TEST-ONLY SETTINGS
    // ==================================================

    private static Razorpay_Settings__mdt getTestSettings() {

        Razorpay_Settings__mdt settings =
            Razorpay_Settings__mdt.getInstance('Test');

        if (
            settings == null ||
            String.isBlank(settings.Key_ID__c) ||
            String.isBlank(settings.Key_Secret__c)
        ) {
            throw new RazorpayPaymentException(
                'Razorpay Test Mode settings are missing. ' +
                'Check the Razorpay_Settings__mdt record named Test.'
            );
        }

        if (!settings.Key_ID__c.startsWith('rzp_test_')) {
            throw new RazorpayPaymentException(
                'Only Razorpay Test Mode keys are allowed by this controller.'
            );
        }

        return settings;
    }


    // ==================================================
    // 4. SEND REQUEST TO RAZORPAY
    // ==================================================

    private static Map<String, Object> sendRazorpayRequest(
        String endpoint,
        String method,
        String requestBody
    ) {

        HttpRequest request = new HttpRequest();

        request.setEndpoint(
            API_ENDPOINT + endpoint
        );

        request.setMethod(method);
        request.setTimeout(20000);

        request.setHeader(
            'Content-Type',
            'application/json'
        );

        if (requestBody != null) {
            request.setBody(requestBody);
        }

        HttpResponse response =
            new Http().send(request);

        Integer statusCode =
            response.getStatusCode();

        if (statusCode < 200 || statusCode >= 300) {
            String bodyText = response.getBody();

            if (String.isBlank(bodyText)) {
                bodyText = '(empty response body)';
            } else if (bodyText.length() > 350) {
                bodyText = bodyText.substring(0, 350);
            }

            throw new RazorpayPaymentException(
                'Razorpay API returned HTTP ' +
                statusCode + ': ' + bodyText
            );
        }

        return (Map<String, Object>)
            JSON.deserializeUntyped(
                response.getBody()
            );
    }


    // ==================================================
    // 5. SIGNATURE COMPARISON
    // ==================================================

    private static Boolean signaturesMatch(
        String expectedSignature,
        String providedSignature
    ) {

        if (
            String.isBlank(expectedSignature) ||
            String.isBlank(providedSignature) ||
            expectedSignature.length() != 64 ||
            providedSignature.length() != 64
        ) {
            return false;
        }

        // Compatibility comparison for this Test Mode demonstration.
        // This is not guaranteed to be constant-time.
        return expectedSignature.equalsIgnoreCase(
            providedSignature
        );
    }
}