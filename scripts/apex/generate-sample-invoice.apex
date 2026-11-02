// Saves an invoice PDF for the first paid demo order to its Files (same as the Generate Invoice button).
Order o = [SELECT Id FROM Order WHERE Payment_Status__c = 'Paid' ORDER BY OrderNumber LIMIT 1];
Id documentId = InvoiceController.saveInvoicePdf(o.Id);
System.debug('INVOICE_VERSION=' + [SELECT Id FROM ContentVersion WHERE ContentDocumentId = :documentId AND IsLatest = TRUE].Id);
