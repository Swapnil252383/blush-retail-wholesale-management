@IsTest
private class GstRateProviderTest {
    @IsTest
    static void garmentsUseFivePercentUpToThreshold() {
        Assert.areEqual(5, GstRateProvider.rateFor('Garments', 475));
        Assert.areEqual(5, GstRateProvider.rateFor('Garments', 1000), 'Exactly Rs. 1,000 is not "greater than" the threshold');
    }

    @IsTest
    static void garmentsUseTwelvePercentAboveThreshold() {
        Assert.areEqual(12, GstRateProvider.rateFor('Garments', 1000.01));
        Assert.areEqual(12, GstRateProvider.rateFor(' garments ', 1400), 'Category match ignores case and spaces');
    }

    @IsTest
    static void jewelleryIsAlwaysThreePercent() {
        Assert.areEqual(3, GstRateProvider.rateFor('Jewellery', 100));
        Assert.areEqual(3, GstRateProvider.rateFor('Jewellery', 50000));
        Assert.areEqual(3, GstRateProvider.rateFor('Jewellery', null));
    }

    @IsTest
    static void unknownOrBlankCategoryHasNoRate() {
        Assert.isNull(GstRateProvider.rateFor('Footwear', 100));
        Assert.isNull(GstRateProvider.rateFor(null, 100));
        Assert.isNull(GstRateProvider.rateFor('', 100));
    }
}