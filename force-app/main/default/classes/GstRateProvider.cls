/**
 * Resolves the GST rate (in percent) for a product category from GST_Rate__mdt.
 * Garments: 5% up to Rs. 1,000 per unit taxable value, 12% above. Jewellery: 3%.
 */
public inherited sharing class GstRateProvider {
    @TestVisible
    private static Map<String, GST_Rate__mdt> rulesByCategory;

    /** @return rate in percent (e.g. 5 for 5%), or null when no rule exists for the category. */
    public static Decimal rateFor(String category, Decimal unitTaxableValue) {
        if (String.isBlank(category)) {
            return null;
        }
        GST_Rate__mdt rule = getRules().get(category.trim().toLowerCase());
        if (rule == null) {
            return null;
        }
        Decimal value = unitTaxableValue == null ? 0 : unitTaxableValue;
        if (rule.Threshold_Amount__c != null && value > rule.Threshold_Amount__c) {
            return rule.Rate_Above_Threshold__c;
        }
        return rule.Rate_Up_To_Threshold__c;
    }

    private static Map<String, GST_Rate__mdt> getRules() {
        if (rulesByCategory == null) {
            rulesByCategory = new Map<String, GST_Rate__mdt>();
            for (GST_Rate__mdt rule : GST_Rate__mdt.getAll().values()) {
                if (String.isNotBlank(rule.Category__c)) {
                    rulesByCategory.put(rule.Category__c.trim().toLowerCase(), rule);
                }
            }
        }
        return rulesByCategory;
    }
}