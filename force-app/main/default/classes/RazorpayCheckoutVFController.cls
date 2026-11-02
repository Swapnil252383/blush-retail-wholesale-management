public with sharing class RazorpayCheckoutVFController {

    // ================================================
    // CREATE PAYMENT ORDER
    // ================================================

    @RemoteAction
    public static Map<String, Object> createOrder(
        String orderId
    ) {

        try {
            if (String.isBlank(orderId)) {
                return failure(
                    'A Salesforce Order ID is required.'
                );
            }

            Id parsedOrderId;

            try {
                parsedOrderId = Id.valueOf(orderId);
            } catch (Exception idError) {
                return failure(
                    'The supplied Salesforce Order ID is invalid.'
                );
            }

            Map<String, Object> paymentData =
                RazorpayPaymentController.createPaymentOrder(
                    parsedOrderId
                );

            return new Map<String, Object>{
                'success' => true,
                'data' => paymentData
            };

        } catch (Exception e) {
            logException('createOrder', e);

            return failure(
                'Apex error [' +
                e.getTypeName() +
                ', line ' +
                e.getLineNumber() +
                ']: ' +
                e.getMessage()
            );
        }
    }


    // ================================================
    // VERIFY PAYMENT
    // ================================================

    @RemoteAction
    public static Map<String, Object> verifyPayment(
        String orderId,
        String transactionId,
        String paymentId,
        String signature
    ) {

        try {
            if (
                String.isBlank(orderId) ||
                String.isBlank(transactionId) ||
                String.isBlank(paymentId) ||
                String.isBlank(signature)
            ) {
                return failure(
                    'Required payment verification details are missing.'
                );
            }

            Id parsedOrderId;
            Id parsedTransactionId;

            try {
                parsedOrderId = Id.valueOf(orderId);

                parsedTransactionId =
                    Id.valueOf(transactionId);

            } catch (Exception idError) {
                return failure(
                    'The Order ID or payment transaction ID is invalid.'
                );
            }

            String verificationMessage =
                RazorpayPaymentController.verifyPayment(
                    parsedOrderId,
                    parsedTransactionId,
                    paymentId,
                    signature
                );

            return new Map<String, Object>{
                'success' => true,
                'message' => verificationMessage
            };

        } catch (Exception e) {
            logException('verifyPayment', e);

            return failure(
                'Apex error [' +
                e.getTypeName() +
                ', line ' +
                e.getLineNumber() +
                ']: ' +
                e.getMessage()
            );
        }
    }


    // ================================================
    // RETURN A FAILURE RESULT
    // ================================================

    private static Map<String, Object> failure(
        String message
    ) {

        return new Map<String, Object>{
            'success' => false,
            'message' => message
        };
    }


    // ================================================
    // LOG DEVELOPMENT ERRORS
    // ================================================

    private static void logException(
        String operation,
        Exception e
    ) {

        System.debug(
            LoggingLevel.ERROR,
            'RazorpayCheckoutVFController.' +
            operation +
            ' exception type: ' +
            e.getTypeName()
        );

        System.debug(
            LoggingLevel.ERROR,
            'RazorpayCheckoutVFController.' +
            operation +
            ' message: ' +
            e.getMessage()
        );

        System.debug(
            LoggingLevel.ERROR,
            'RazorpayCheckoutVFController.' +
            operation +
            ' line: ' +
            e.getLineNumber()
        );

        System.debug(
            LoggingLevel.ERROR,
            'RazorpayCheckoutVFController.' +
            operation +
            ' stack: ' +
            e.getStackTraceString()
        );
    }
}