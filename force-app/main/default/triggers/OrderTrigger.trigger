trigger OrderTrigger on Order (before insert, before update, before delete, after insert, after update) {
    if (Trigger.isBefore && Trigger.isInsert) {
        OrderService.beforeInsert(Trigger.new);
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        OrderService.beforeUpdate(Trigger.new, Trigger.oldMap);
    } else if (Trigger.isBefore && Trigger.isDelete) {
        OrderService.beforeDelete(Trigger.old);
    } else if (Trigger.isAfter && Trigger.isInsert) {
        OrderService.afterInsert(Trigger.new);
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        OrderService.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}