/**
 * Shared constants and record type helpers for the Blush implementation.
 */
public inherited sharing class BlushConstants {
    public static final String CHANNEL_RETAIL = 'Retail';
    public static final String CHANNEL_WHOLESALE = 'Wholesale';

    public static final String RETAIL_PRICEBOOK = 'Blush Retail Price Book';
    public static final String WHOLESALE_PRICEBOOK = 'Blush Wholesale Price Book';
    /** Wholesale price = base price less 30%. */
    public static final Decimal WHOLESALE_PRICE_FACTOR = 0.70;

    public static final String TAX_TYPE_INTRA_STATE = 'CGST + SGST';
    public static final String TAX_TYPE_INTER_STATE = 'IGST';
    public static final String HOME_STATE_CODE = 'MH';
    public static final String HOME_STATE_NAME = 'Maharashtra';
    public static final Set<String> HOME_COUNTRY_VALUES = new Set<String>{ 'IN', 'INDIA' };

    public static final String PAYMENT_STATUS_PAID = 'Paid';
    public static final String PERMISSION_EDIT_PAID_ORDERS = 'Edit_Paid_Orders';

    /** Line discount percentage above which an order needs approval. */
    public static final Decimal MAX_DISCOUNT_WITHOUT_APPROVAL = 10;
    public static final String APPROVAL_PROCESS_NAME = 'Order_Discount_Approval';
    public static final String APPROVAL_NOT_REQUIRED = 'Not Required';
    public static final String APPROVAL_REQUIRED = 'Required';
    public static final String APPROVAL_PENDING = 'Pending';
    public static final String APPROVAL_APPROVED = 'Approved';
    public static final String APPROVAL_REJECTED = 'Rejected';

    public static Id recordTypeId(SObjectType objectType, String developerName) {
        Schema.RecordTypeInfo info = objectType.getDescribe().getRecordTypeInfosByDeveloperName().get(developerName);
        return info == null ? null : info.getRecordTypeId();
    }

    /** Returns the channel (Retail/Wholesale) for a record type id, or null for other record types. */
    public static String channelFor(SObjectType objectType, Id recordTypeId) {
        if (recordTypeId == null) {
            return null;
        }
        Schema.RecordTypeInfo info = objectType.getDescribe().getRecordTypeInfosById().get(recordTypeId);
        if (info == null) {
            return null;
        }
        String devName = info.getDeveloperName();
        return devName == CHANNEL_RETAIL || devName == CHANNEL_WHOLESALE ? devName : null;
    }

    /** Channel for a record, defaulting to Retail when no Blush record type is set. */
    public static String channelOrDefault(SObjectType objectType, Id recordTypeId) {
        String channel = channelFor(objectType, recordTypeId);
        return channel == null ? CHANNEL_RETAIL : channel;
    }
}