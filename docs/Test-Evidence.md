# Blush - Apex Test Evidence

Run: 2026-10-19T16:53:03.000Z  |  Org: swapnil.rupnar.875e97216098@agentforce.com

| Outcome | Tests run | Passed | Failed | Coverage (Blush classes) |
|---|---|---|---|---|
| Passed | 83 | 83 | 0 | see below |

## Coverage

| Class / Trigger | Coverage |
|---|---|
| ProductPricebookService | 100% |
| OrderItemTaxService | 100% |
| OpportunityFollowUpBatch | 100% |
| InvoiceController | 100% |
| OrderService | 100% |
| OpportunityCustomerService | 100% |
| GstRateProvider | 100% |
| PricebookService | 100% |
| BlushConstants | 100% |
| OrderItemTrigger | 100% |
| Product2Trigger | 100% |
| OrderTrigger | 100% |
| OpportunityTrigger | 100% |

## Test methods

| Test | Outcome | Time (ms) |
|---|---|---|
| BlushConstantsTest.channelForBlushRecordTypes | Pass | 44 |
| BlushConstantsTest.channelForOtherRecordTypesIsNull | Pass | 11 |
| GstRateProviderTest.garmentsUseFivePercentUpToThreshold | Pass | 51 |
| GstRateProviderTest.garmentsUseTwelvePercentAboveThreshold | Pass | 7 |
| GstRateProviderTest.jewelleryIsAlwaysThreePercent | Pass | 5 |
| GstRateProviderTest.unknownOrBlankCategoryHasNoRate | Pass | 5 |
| InvoiceControllerTest.interStateInvoiceShowsIgst | Pass | 808 |
| InvoiceControllerTest.loadsInvoiceDataForIntraStateOrder | Pass | 443 |
| InvoiceControllerTest.orderWithoutStoreFallsBackToBrandName | Pass | 699 |
| InvoiceControllerTest.saveInvoiceReportsErrors | Pass | 82 |
| InvoiceControllerTest.savesInvoicePdfToOrderFiles | Pass | 1073 |
| OpportunityCustomerServiceTest.bulkOpportunitiesCreateOneCustomerEach | Pass | 5550 |
| OpportunityCustomerServiceTest.changingRecordTypeSwitchesPricebook | Pass | 408 |
| OpportunityCustomerServiceTest.clearingTheAccountOnUpdateResolvesTheCustomerAgain | Pass | 551 |
| OpportunityCustomerServiceTest.emailMatchWinsOverPhoneMatch | Pass | 875 |
| OpportunityCustomerServiceTest.existingContactIsReusedInsteadOfCreatingDuplicate | Pass | 480 |
| OpportunityCustomerServiceTest.failedLeadConversionIsReportedOnTheOpportunity | Pass | 153370 |
| OpportunityCustomerServiceTest.matchingLeadByEmailIsConverted | Pass | 824 |
| OpportunityCustomerServiceTest.matchingLeadByPhoneIgnoresFormatting | Pass | 543 |
| OpportunityCustomerServiceTest.missingChannelPricebookIsReported | Pass | 653 |
| OpportunityCustomerServiceTest.newCustomerRequiresName | Pass | 44 |
| OpportunityCustomerServiceTest.newRetailCustomerIsCreatedFromOpportunity | Pass | 337 |
| OpportunityCustomerServiceTest.newWholesaleCustomerUsesCompanyNameAndWholesalePricing | Pass | 297 |
| OpportunityCustomerServiceTest.opportunityWithoutAccountEmailOrPhoneIsRejected | Pass | 28 |
| OpportunityCustomerServiceTest.phoneNormalization | Pass | 8 |
| OpportunityCustomerServiceTest.queueOwnedLeadIsConvertedToTheCurrentUser | Pass | 793 |
| OpportunityCustomerServiceTest.retailOpportunityCannotUseWholesaleAccount | Pass | 108 |
| OpportunityCustomerServiceTest.retailOpportunityCannotUseWholesalePricebook | Pass | 342 |
| OpportunityCustomerServiceTest.selectedAccountIsKept | Pass | 141 |
| OpportunityCustomerServiceTest.singleWordNameBecomesLastName | Pass | 305 |
| OpportunityCustomerServiceTest.switchingToAContactThatAlreadyHasARoleAddsNoDuplicate | Pass | 503 |
| OpportunityFollowUpBatchTest.createsAtMostOneReminderPerOpportunity | Pass | 375 |
| OpportunityFollowUpBatchTest.noQualifyingActivitiesCreatesNothing | Pass | 349 |
| OpportunityFollowUpBatchTest.reminderTasksDoNotTriggerFurtherReminders | Pass | 166 |
| OpportunityFollowUpBatchTest.remindsOnlyForOpenOpportunitiesWithRecentIncompleteActivities | Pass | 351 |
| OpportunityFollowUpBatchTest.schedulerQueuesTheBatch | Pass | 171 |
| OpportunityFollowUpBatchTest.windowBoundariesAreInclusive | Pass | 200 |
| OrderItemTaxServiceTest.approvedDiscountAllowsPayment | Pass | 1654 |
| OrderItemTaxServiceTest.approvedOrderIsResubmittedWhenDiscountIncreases | Pass | 2836 |
| OrderItemTaxServiceTest.approvedOrderStaysApprovedWhenDiscountDoesNotIncrease | Pass | 1421 |
| OrderItemTaxServiceTest.bulkLinesAreTaxedInOneTransaction | Pass | 1570 |
| OrderItemTaxServiceTest.commissionAtExactlyOneThousandIsOnePercent | Pass | 675 |
| OrderItemTaxServiceTest.deletingALineUpdatesTotals | Pass | 1035 |
| OrderItemTaxServiceTest.discountAboveTenPercentIsSubmittedForApproval | Pass | 1033 |
| OrderItemTaxServiceTest.discountAboveUnitPriceIsRejected | Pass | 385 |
| OrderItemTaxServiceTest.discountOfExactlyTenPercentNeedsNoApproval | Pass | 462 |
| OrderItemTaxServiceTest.jewelleryUsesThreePercentAndOrderTotalsAddUp | Pass | 469 |
| OrderItemTaxServiceTest.maharashtraGarmentLineSplitsGstIntoCgstAndSgst | Pass | 470 |
| OrderItemTaxServiceTest.managerCanCorrectLinesOnPaidOrder | Pass | 76945 |
| OrderItemTaxServiceTest.outOfStateGarmentAboveThousandUsesTwelvePercentIgst | Pass | 560 |
| OrderItemTaxServiceTest.paidOrderLinesCannotBeChangedOrDeletedBySalesUser | Pass | 2211 |
| OrderItemTaxServiceTest.unapprovedDiscountBlocksPayment | Pass | 1129 |
| OrderItemTaxServiceTest.unknownCategoryCannotBeTaxed | Pass | 92 |
| OrderItemTaxServiceTest.wholesaleOrderUsesWholesalePrice | Pass | 511 |
| OrderServiceTest.changingBillingStateRecalculatesTaxes | Pass | 1325 |
| OrderServiceTest.changingTheStatePicklistCodeSwitchesToIgst | Pass | 369 |
| OrderServiceTest.clearedSalesRepIsRestoredToOwner | Pass | 460 |
| OrderServiceTest.managerWithPermissionCanEditPaidOrder | Pass | 4984 |
| OrderServiceTest.orderFromOpportunityInheritsCustomerChannelRepAndProducts | Pass | 1731 |
| OrderServiceTest.orderKeepsItsOwnBillingAddress | Pass | 439 |
| OrderServiceTest.orderWithoutRecordTypeDefaultsToRetail | Pass | 326 |
| OrderServiceTest.paidOrderCannotBeEditedOrDeletedBySalesUser | Pass | 2826 |
| OrderServiceTest.paymentModeIsRequiredWhenPaid | Pass | 450 |
| OrderServiceTest.retailOrderCannotUseWholesaleAccount | Pass | 303 |
| OrderServiceTest.retailOrderCannotUseWholesalePricebook | Pass | 278 |
| OrderServiceTest.taxTypeRules | Pass | 110 |
| OrderServiceTest.unpaidOrderCanBeEditedAndDeleted | Pass | 554 |
| ProductPricebookServiceTest.addingAChannelLaterCreatesTheEntry | Pass | 541 |
| ProductPricebookServiceTest.basePriceChangeUpdatesAllPrices | Pass | 432 |
| ProductPricebookServiceTest.bulkInsertCreatesEntriesForEveryProduct | Pass | 4560 |
| ProductPricebookServiceTest.channelWithoutBasePriceIsRejected | Pass | 130 |
| ProductPricebookServiceTest.deactivatingProductDeactivatesChannelEntries | Pass | 431 |
| ProductPricebookServiceTest.missingPricebooksBlockChannelAssignment | Pass | 96 |
| ProductPricebookServiceTest.productForBothChannelsGetsRetailAndWholesalePrices | Pass | 270 |
| ProductPricebookServiceTest.productWithoutChannelGetsNoEntries | Pass | 200 |
| ProductPricebookServiceTest.removingAChannelDeactivatesTheEntry | Pass | 419 |
| ProductPricebookServiceTest.retailOnlyProductHasNoWholesaleEntry | Pass | 275 |
| ProductPricebookServiceTest.unrelatedUpdateDoesNotTouchEntries | Pass | 344 |
