/**
 * Order product tax and totals (requirements E.18 - E.20, G.25 - G.29).
 *   Taxable amount = (Unit Price - Discount per unit) x Quantity
 *   GST rate       = GST_Rate__mdt by product category (garment slab uses the per-unit taxable value)
 *   Tax split      = CGST + SGST (half each) for Maharashtra, otherwise IGST
 *   Net price      = Taxable amount + Taxes
 * Order totals are rolled up after every change; an order with any line discount above 10% is
 * submitted to the "Order Discount Approval" process automatically.
 */
public with sharing class OrderItemTaxService {
    public static void calculate(List<OrderItem> items) {
        Set<Id> orderIds = new Set<Id>();
        Set<Id> entryIds = new Set<Id>();
        for (OrderItem item : items) {
            orderIds.add(item.OrderId);
            entryIds.add(item.PricebookEntryId);
        }
        Map<Id, Order> orders = new Map<Id, Order>([SELECT Id, Tax_Type__c FROM Order WHERE Id IN :orderIds]);
        Map<Id, PricebookEntry> entries = new Map<Id, PricebookEntry>(
            [SELECT Id, Product2.Category__c FROM PricebookEntry WHERE Id IN :entryIds]
        );
        for (OrderItem item : items) {
            PricebookEntry entry = entries.get(item.PricebookEntryId);
            Order parent = orders.get(item.OrderId);
            calculateLine(item, entry == null ? null : entry.Product2.Category__c, parent == null ? null : parent.Tax_Type__c);
        }
    }

    @TestVisible
    private static void calculateLine(OrderItem item, String category, String taxType) {
        Decimal unitPrice = item.UnitPrice == null ? 0 : item.UnitPrice;
        Decimal discount = item.Discount__c == null ? 0 : item.Discount__c;
        Decimal quantity = item.Quantity == null ? 0 : item.Quantity;
        if (discount < 0 || discount > unitPrice) {
            item.Discount__c.addError('Discount must be between 0 and the unit price.');
            return;
        }
        Decimal rate = GstRateProvider.rateFor(category, unitPrice - discount);
        if (rate == null) {
            item.addError('No GST rate is configured for product category "' + category + '". Set the product Category to Garments or Jewellery.');
            return;
        }

        Decimal taxable = ((unitPrice - discount) * quantity).setScale(2, RoundingMode.HALF_UP);
        Decimal tax = (taxable * rate / 100).setScale(2, RoundingMode.HALF_UP);
        item.Discount_Percent__c = unitPrice == 0 ? 0 : (discount / unitPrice * 100).setScale(2, RoundingMode.HALF_UP);
        item.Line_Discount__c = (discount * quantity).setScale(2, RoundingMode.HALF_UP);
        item.Taxable_Amount__c = taxable;
        item.GST_Rate__c = rate;
        item.Total_Tax__c = tax;
        if (taxType == BlushConstants.TAX_TYPE_INTER_STATE) {
            item.IGST__c = tax;
            item.CGST__c = 0;
            item.SGST__c = 0;
        } else {
            item.CGST__c = (tax / 2).setScale(2, RoundingMode.HALF_UP);
            item.SGST__c = tax - item.CGST__c;
            item.IGST__c = 0;
        }
        item.Net_Price__c = taxable + tax;
    }

    public static void preventChangesOnPaidOrders(List<OrderItem> items) {
        if (FeatureManagement.checkPermission(BlushConstants.PERMISSION_EDIT_PAID_ORDERS)) {
            return;
        }
        Set<Id> orderIds = new Set<Id>();
        for (OrderItem item : items) {
            orderIds.add(item.OrderId);
        }
        Map<Id, Order> paid = new Map<Id, Order>(
            [SELECT Id FROM Order WHERE Id IN :orderIds AND Payment_Status__c = :BlushConstants.PAYMENT_STATUS_PAID]
        );
        for (OrderItem item : items) {
            if (paid.containsKey(item.OrderId)) {
                item.addError('Products on a paid order can no longer be changed.');
            }
        }
    }

    public static void rollupOrders(Set<Id> orderIds) {
        Map<Id, Order> orders = new Map<Id, Order>(
            [SELECT Id, Approval_Status__c, Max_Discount_Percent__c FROM Order WHERE Id IN :orderIds]
        );
        Map<Id, AggregateResult> totalsByOrder = new Map<Id, AggregateResult>();
        for (AggregateResult totals : [
            SELECT
                OrderId orderId,
                SUM(Line_Discount__c) discount,
                SUM(Taxable_Amount__c) taxable,
                SUM(CGST__c) cgst,
                SUM(SGST__c) sgst,
                SUM(IGST__c) igst,
                SUM(Total_Tax__c) tax,
                SUM(Net_Price__c) net,
                MAX(Discount_Percent__c) maxDiscount
            FROM OrderItem
            WHERE OrderId IN :orderIds
            GROUP BY OrderId
        ]) {
            totalsByOrder.put((Id) totals.get('orderId'), totals);
        }

        List<Order> updates = new List<Order>();
        List<Id> toSubmit = new List<Id>();
        for (Order o : orders.values()) {
            AggregateResult totals = totalsByOrder.get(o.Id);
            Decimal maxDiscount = amount(totals, 'maxDiscount');
            Order changed = new Order(
                Id = o.Id,
                Total_Discount__c = amount(totals, 'discount'),
                Effective_Order_Amount__c = amount(totals, 'taxable'),
                Total_CGST__c = amount(totals, 'cgst'),
                Total_SGST__c = amount(totals, 'sgst'),
                Total_IGST__c = amount(totals, 'igst'),
                Total_GST__c = amount(totals, 'tax'),
                Net_Amount__c = amount(totals, 'net'),
                Max_Discount_Percent__c = maxDiscount
            );
            String status = o.Approval_Status__c;
            Decimal previousMax = o.Max_Discount_Percent__c == null ? 0 : o.Max_Discount_Percent__c;
            if (maxDiscount <= BlushConstants.MAX_DISCOUNT_WITHOUT_APPROVAL) {
                if (status != BlushConstants.APPROVAL_PENDING) {
                    changed.Approval_Status__c = BlushConstants.APPROVAL_NOT_REQUIRED;
                }
            } else if (
                String.isBlank(status) ||
                status == BlushConstants.APPROVAL_NOT_REQUIRED ||
                status == BlushConstants.APPROVAL_REQUIRED ||
                (maxDiscount > previousMax && (status == BlushConstants.APPROVAL_APPROVED || status == BlushConstants.APPROVAL_REJECTED))
            ) {
                changed.Approval_Status__c = BlushConstants.APPROVAL_REQUIRED;
                toSubmit.add(o.Id);
            }
            updates.add(changed);
        }
        update updates;
        submitForApproval(toSubmit);
    }

    /** Submission failures leave the order as "Required"; users can still use Submit for Approval. */
    private static void submitForApproval(List<Id> orderIds) {
        if (orderIds.isEmpty()) {
            return;
        }
        List<Approval.ProcessSubmitRequest> requests = new List<Approval.ProcessSubmitRequest>();
        for (Id orderId : orderIds) {
            Approval.ProcessSubmitRequest request = new Approval.ProcessSubmitRequest();
            request.setObjectId(orderId);
            request.setProcessDefinitionNameOrId(BlushConstants.APPROVAL_PROCESS_NAME);
            request.setComments('Automatically submitted: a line discount is above ' + BlushConstants.MAX_DISCOUNT_WITHOUT_APPROVAL + '%.');
            requests.add(request);
        }
        Approval.process(requests, false);
    }

    private static Decimal amount(AggregateResult totals, String alias) {
        if (totals == null || totals.get(alias) == null) {
            return 0;
        }
        return (Decimal) totals.get(alias);
    }
}