trigger OrderItemTrigger on OrderItem (before insert, before update, before delete, after insert, after update, after delete) {
    if (Trigger.isBefore) {
        if (Trigger.isDelete) {
            OrderItemTaxService.preventChangesOnPaidOrders(Trigger.old);
        } else {
            OrderItemTaxService.calculate(Trigger.new);
        }
        return;
    }
    Set<Id> orderIds = new Set<Id>();
    for (OrderItem item : Trigger.isDelete ? Trigger.old : Trigger.new) {
        orderIds.add(item.OrderId);
    }
    OrderItemTaxService.rollupOrders(orderIds);
}