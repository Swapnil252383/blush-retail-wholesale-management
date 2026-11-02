/**
 * Looks up the standard price book and the Blush channel price books (cached per transaction).
 */
public inherited sharing class PricebookService {
    private static Id standardPricebookId;
    private static Map<String, Id> pricebookIdByChannel;

    public static Id getStandardPricebookId() {
        if (standardPricebookId == null) {
            // Tests cannot query the standard price book without SeeAllData.
            standardPricebookId = Test.isRunningTest() ? Test.getStandardPricebookId() : [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1].Id;
        }
        return standardPricebookId;
    }

    /** Active price book for a channel (Retail/Wholesale), or null if it has not been set up. */
    public static Id getChannelPricebookId(String channel) {
        if (pricebookIdByChannel == null) {
            pricebookIdByChannel = new Map<String, Id>();
            for (Pricebook2 pb : [
                SELECT Id, Name
                FROM Pricebook2
                WHERE IsActive = TRUE AND Name IN :new List<String>{ BlushConstants.RETAIL_PRICEBOOK, BlushConstants.WHOLESALE_PRICEBOOK }
            ]) {
                pricebookIdByChannel.put(pb.Name == BlushConstants.RETAIL_PRICEBOOK ? BlushConstants.CHANNEL_RETAIL : BlushConstants.CHANNEL_WHOLESALE, pb.Id);
            }
        }
        return pricebookIdByChannel.get(channel);
    }

    public static String pricebookName(String channel) {
        return channel == BlushConstants.CHANNEL_WHOLESALE ? BlushConstants.WHOLESALE_PRICEBOOK : BlushConstants.RETAIL_PRICEBOOK;
    }

    @TestVisible
    private static void clearCache() {
        standardPricebookId = null;
        pricebookIdByChannel = null;
    }
}