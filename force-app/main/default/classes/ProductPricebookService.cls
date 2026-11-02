/**
 * Keeps price book entries in sync with Product2.Sales_Channel__c and Base_Price__c so sales users
 * can sell a product as soon as it is made available for a channel (requirement C.12).
 *   Standard price book  : base price (required by the platform before custom entries)
 *   Retail price book    : base price
 *   Wholesale price book : base price less 30%
 * Removing a channel deactivates the entry instead of deleting it, so historical lines stay valid.
 */
public with sharing class ProductPricebookService {
    public static void syncPricebookEntries(List<Product2> products, Map<Id, Product2> oldMap) {
        List<Product2> changed = new List<Product2>();
        for (Product2 product : products) {
            Product2 old = oldMap == null ? null : oldMap.get(product.Id);
            if (
                old == null ||
                old.Sales_Channel__c != product.Sales_Channel__c ||
                old.Base_Price__c != product.Base_Price__c ||
                old.IsActive != product.IsActive
            ) {
                changed.add(product);
            }
        }
        if (changed.isEmpty()) {
            return;
        }

        Id standardId = PricebookService.getStandardPricebookId();
        Id retailId = PricebookService.getChannelPricebookId(BlushConstants.CHANNEL_RETAIL);
        Id wholesaleId = PricebookService.getChannelPricebookId(BlushConstants.CHANNEL_WHOLESALE);

        Map<String, PricebookEntry> existing = new Map<String, PricebookEntry>();
        Set<Id> productsWithEntries = new Set<Id>();
        for (PricebookEntry entry : [
            SELECT Id, Pricebook2Id, Product2Id, UnitPrice, IsActive
            FROM PricebookEntry
            WHERE Product2Id IN :changed AND Pricebook2Id IN :new Set<Id>{ standardId, retailId, wholesaleId }
        ]) {
            existing.put(key(entry.Pricebook2Id, entry.Product2Id), entry);
            productsWithEntries.add(entry.Product2Id);
        }

        List<PricebookEntry> standardEntries = new List<PricebookEntry>();
        List<PricebookEntry> channelEntries = new List<PricebookEntry>();
        for (Product2 product : changed) {
            Set<String> channels = parseChannels(product.Sales_Channel__c);
            if (channels.isEmpty() && !productsWithEntries.contains(product.Id)) {
                continue;
            }
            Decimal basePrice = product.Base_Price__c == null ? 0 : product.Base_Price__c;
            Boolean sellRetail = product.IsActive && channels.contains(BlushConstants.CHANNEL_RETAIL);
            Boolean sellWholesale = product.IsActive && channels.contains(BlushConstants.CHANNEL_WHOLESALE);

            if ((sellRetail && retailId == null) || (sellWholesale && wholesaleId == null)) {
                product.addError(
                    'Blush price books are missing or inactive. Ask an administrator to create "' +
                        BlushConstants.RETAIL_PRICEBOOK +
                        '" and "' +
                        BlushConstants.WHOLESALE_PRICEBOOK +
                        '".'
                );
                continue;
            }

            // The standard entry stays active once created so channel entries remain valid.
            Boolean standardExists = existing.containsKey(key(standardId, product.Id));
            addEntry(standardEntries, existing, standardId, product.Id, basePrice, standardExists || sellRetail || sellWholesale);
            if (retailId != null) {
                addEntry(channelEntries, existing, retailId, product.Id, basePrice, sellRetail);
            }
            if (wholesaleId != null) {
                Decimal wholesalePrice = (basePrice * BlushConstants.WHOLESALE_PRICE_FACTOR).setScale(2, RoundingMode.HALF_UP);
                addEntry(channelEntries, existing, wholesaleId, product.Id, wholesalePrice, sellWholesale);
            }
        }
        upsert standardEntries;
        upsert channelEntries;
    }

    private static void addEntry(
        List<PricebookEntry> target,
        Map<String, PricebookEntry> existing,
        Id pricebookId,
        Id productId,
        Decimal price,
        Boolean active
    ) {
        PricebookEntry current = existing.get(key(pricebookId, productId));
        if (current == null) {
            if (active) {
                target.add(
                    new PricebookEntry(Pricebook2Id = pricebookId, Product2Id = productId, UnitPrice = price, IsActive = true, UseStandardPrice = false)
                );
            }
        } else if (current.UnitPrice != price || current.IsActive != active) {
            target.add(new PricebookEntry(Id = current.Id, UnitPrice = price, IsActive = active));
        }
    }

    private static Set<String> parseChannels(String value) {
        Set<String> channels = new Set<String>();
        if (String.isNotBlank(value)) {
            for (String channel : value.split(';')) {
                channels.add(channel.trim());
            }
        }
        return channels;
    }

    private static String key(Id pricebookId, Id productId) {
        return pricebookId + '|' + productId;
    }
}