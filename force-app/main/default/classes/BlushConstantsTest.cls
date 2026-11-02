@IsTest
private class BlushConstantsTest {
    @IsTest
    static void channelForBlushRecordTypes() {
        Id retail = BlushConstants.recordTypeId(Order.SObjectType, BlushConstants.CHANNEL_RETAIL);
        Id wholesale = BlushConstants.recordTypeId(Order.SObjectType, BlushConstants.CHANNEL_WHOLESALE);
        Assert.areEqual(BlushConstants.CHANNEL_RETAIL, BlushConstants.channelFor(Order.SObjectType, retail));
        Assert.areEqual(BlushConstants.CHANNEL_WHOLESALE, BlushConstants.channelFor(Order.SObjectType, wholesale));
    }

    @IsTest
    static void channelForOtherRecordTypesIsNull() {
        Id master = Order.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('Master').getRecordTypeId();
        Assert.isNull(BlushConstants.channelFor(Order.SObjectType, master));
        Assert.isNull(BlushConstants.channelFor(Order.SObjectType, null));
        Assert.isNull(BlushConstants.channelFor(Order.SObjectType, BlushConstants.recordTypeId(Account.SObjectType, 'Retail')), 'Record type of another object');
        Assert.areEqual(BlushConstants.CHANNEL_RETAIL, BlushConstants.channelOrDefault(Order.SObjectType, null));
        Assert.isNull(BlushConstants.recordTypeId(Order.SObjectType, 'DoesNotExist'));
    }
}