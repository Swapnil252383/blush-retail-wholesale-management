/**
 * Order automation:
 *  - Defaults from the related opportunity: account, record type (Retail/Wholesale), price book and
 *    Sales Representative (the opportunity owner handles the customer and earns the commission).
 *  - Copies the account billing address, default store and tax type (CGST + SGST vs IGST).
 *  - Copies opportunity products into order products.
 *  - Re-calculates line taxes when the billing state changes.
 *  - Blocks deleting paid orders (requirement F.22; editing is blocked by validation rules).
 */
public with sharing class OrderService {
    private static final Boolean HAS_STATE_CODES = Schema.SObjectType.Order.fields.getMap().containsKey('billingstatecode');

    public static void beforeInsert(List<Order> orders) {
        Set<Id> opportunityIds = new Set<Id>();
        for (Order o : orders) {
            if (o.OpportunityId != null) {
                opportunityIds.add(o.OpportunityId);
            }
        }
        Map<Id, Opportunity> opportunities = new Map<Id, Opportunity>(
            [SELECT Id, OwnerId, AccountId, RecordTypeId FROM Opportunity WHERE Id IN :opportunityIds]
        );

        Set<Id> accountIds = new Set<Id>();
        for (Order o : orders) {
            Opportunity opp = opportunities.get(o.OpportunityId);
            if (opp != null) {
                if (o.AccountId == null) {
                    o.AccountId = opp.AccountId;
                }
                if (o.Sales_Representative__c == null) {
                    o.Sales_Representative__c = opp.OwnerId;
                }
                String oppChannel = BlushConstants.channelFor(Opportunity.SObjectType, opp.RecordTypeId);
                if (oppChannel != null) {
                    o.RecordTypeId = BlushConstants.recordTypeId(Order.SObjectType, oppChannel);
                }
            }
            if (o.AccountId != null) {
                accountIds.add(o.AccountId);
            }
        }

        Map<Id, Account> accounts = new Map<Id, Account>(
            [
                SELECT Id, RecordTypeId, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry
                FROM Account
                WHERE Id IN :accountIds
            ]
        );
        Id defaultStoreId = getDefaultStoreId();

        for (Order o : orders) {
            String channel = BlushConstants.channelOrDefault(Order.SObjectType, o.RecordTypeId);
            o.RecordTypeId = BlushConstants.recordTypeId(Order.SObjectType, channel);
            Account acc = accounts.get(o.AccountId);
            if (acc != null) {
                String accountChannel = BlushConstants.channelFor(Account.SObjectType, acc.RecordTypeId);
                if (accountChannel != null && accountChannel != channel) {
                    o.addError('A ' + channel + ' order must be placed for a ' + channel + ' account. The selected account is ' + accountChannel + '.');
                    continue;
                }
                copyBillingAddress(o, acc);
            }

            Id expectedPricebook = PricebookService.getChannelPricebookId(channel);
            if (o.Pricebook2Id == null) {
                o.Pricebook2Id = expectedPricebook;
            } else if (expectedPricebook != null && o.Pricebook2Id != expectedPricebook) {
                o.addError(channel + ' orders must use the "' + PricebookService.pricebookName(channel) + '".');
                continue;
            }

            if (o.Sales_Representative__c == null) {
                o.Sales_Representative__c = o.OwnerId != null ? o.OwnerId : UserInfo.getUserId();
            }
            if (o.Store__c == null) {
                o.Store__c = defaultStoreId;
            }
            o.Tax_Type__c = taxTypeFor(o, null);
        }
    }

    public static void beforeUpdate(List<Order> orders, Map<Id, Order> oldMap) {
        for (Order o : orders) {
            Order old = oldMap.get(o.Id);
            if (o.Sales_Representative__c == null) {
                o.Sales_Representative__c = o.OwnerId;
            }
            if (String.isBlank(o.Tax_Type__c) || billingStateChanged(o, old)) {
                o.Tax_Type__c = taxTypeFor(o, old);
            }
        }
    }

    public static void afterInsert(List<Order> orders) {
        copyOpportunityProducts(orders);
    }

    public static void afterUpdate(List<Order> orders, Map<Id, Order> oldMap) {
        Set<Id> taxTypeChanged = new Set<Id>();
        for (Order o : orders) {
            if (o.Tax_Type__c != oldMap.get(o.Id).Tax_Type__c) {
                taxTypeChanged.add(o.Id);
            }
        }
        if (!taxTypeChanged.isEmpty()) {
            // Saving the lines re-runs OrderItemTaxService with the new tax type.
            update [SELECT Id FROM OrderItem WHERE OrderId IN :taxTypeChanged];
        }
    }

    public static void beforeDelete(List<Order> orders) {
        if (FeatureManagement.checkPermission(BlushConstants.PERMISSION_EDIT_PAID_ORDERS)) {
            return;
        }
        for (Order o : orders) {
            if (o.Payment_Status__c == BlushConstants.PAYMENT_STATUS_PAID) {
                o.addError('Paid orders cannot be deleted.');
            }
        }
    }

    /**
     * CGST + SGST when the billing address is in Maharashtra, India; IGST otherwise.
     * A blank billing state is treated as a counter sale at a Maharashtra store (intra-state).
     */
    public static String taxTypeFor(Order o, Order old) {
        String state = o.BillingState;
        String country = o.BillingCountry;
        if (HAS_STATE_CODES) {
            String stateCode = (String) o.get('BillingStateCode');
            Boolean onlyNameChanged = old != null && o.BillingState != old.BillingState && stateCode == (String) old.get('BillingStateCode');
            if (String.isNotBlank(stateCode) && !onlyNameChanged) {
                state = stateCode;
                String countryCode = (String) o.get('BillingCountryCode');
                country = String.isNotBlank(countryCode) ? countryCode : country;
            }
        }
        if (String.isBlank(state)) {
            return BlushConstants.TAX_TYPE_INTRA_STATE;
        }
        Boolean inIndia = String.isBlank(country) || BlushConstants.HOME_COUNTRY_VALUES.contains(country.trim().toUpperCase());
        Boolean homeState = state.trim().equalsIgnoreCase(BlushConstants.HOME_STATE_CODE) || state.trim().equalsIgnoreCase(BlushConstants.HOME_STATE_NAME);
        return inIndia && homeState ? BlushConstants.TAX_TYPE_INTRA_STATE : BlushConstants.TAX_TYPE_INTER_STATE;
    }

    private static Boolean billingStateChanged(Order o, Order old) {
        if (o.BillingState != old.BillingState || o.BillingCountry != old.BillingCountry) {
            return true;
        }
        return HAS_STATE_CODES && (o.get('BillingStateCode') != old.get('BillingStateCode') || o.get('BillingCountryCode') != old.get('BillingCountryCode'));
    }

    private static void copyBillingAddress(Order o, Account account) {
        Boolean orderHasAddress = String.isNotBlank(o.BillingStreet) || String.isNotBlank(o.BillingCity) || String.isNotBlank(o.BillingState);
        if (HAS_STATE_CODES) {
            orderHasAddress = orderHasAddress || String.isNotBlank((String) o.get('BillingStateCode'));
        }
        if (orderHasAddress) {
            return;
        }
        o.BillingStreet = account.BillingStreet;
        o.BillingCity = account.BillingCity;
        o.BillingPostalCode = account.BillingPostalCode;
        o.BillingCountry = account.BillingCountry;
        o.BillingState = account.BillingState;
    }

    private static Id getDefaultStoreId() {
        List<Store__c> stores = [SELECT Id FROM Store__c ORDER BY Is_Default__c DESC, CreatedDate ASC LIMIT 1];
        return stores.isEmpty() ? null : stores[0].Id;
    }

    private static void copyOpportunityProducts(List<Order> orders) {
        Map<Id, List<Order>> ordersByOpportunity = new Map<Id, List<Order>>();
        for (Order o : orders) {
            if (o.OpportunityId != null) {
                if (!ordersByOpportunity.containsKey(o.OpportunityId)) {
                    ordersByOpportunity.put(o.OpportunityId, new List<Order>());
                }
                ordersByOpportunity.get(o.OpportunityId).add(o);
            }
        }
        if (ordersByOpportunity.isEmpty()) {
            return;
        }
        List<OrderItem> items = new List<OrderItem>();
        for (OpportunityLineItem line : [
            SELECT OpportunityId, PricebookEntryId, PricebookEntry.Pricebook2Id, Quantity, UnitPrice, Discount, Description
            FROM OpportunityLineItem
            WHERE OpportunityId IN :ordersByOpportunity.keySet()
        ]) {
            for (Order o : ordersByOpportunity.get(line.OpportunityId)) {
                // Lines from another price book cannot be added to this order.
                if (line.PricebookEntry.Pricebook2Id == o.Pricebook2Id) {
                    Decimal discountPerUnit = line.Discount == null ? null : (line.UnitPrice * line.Discount / 100).setScale(2, RoundingMode.HALF_UP);
                    items.add(
                        new OrderItem(
                            OrderId = o.Id,
                            PricebookEntryId = line.PricebookEntryId,
                            Quantity = line.Quantity,
                            UnitPrice = line.UnitPrice,
                            Discount__c = discountPerUnit,
                            Description = line.Description
                        )
                    );
                }
            }
        }
        insert items;
    }
}