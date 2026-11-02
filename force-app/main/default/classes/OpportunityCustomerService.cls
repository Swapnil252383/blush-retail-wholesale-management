/**
 * Opportunity automation (requirements A.3 - A.5, C.13):
 *  1. When an opportunity has no Account, find the customer from Customer Email / Customer Phone:
 *       existing Contact  -> reuse its Account (prevents duplicate customers)
 *       open Lead         -> convert it (no new opportunity) and use the new Account/Contact
 *       nothing found     -> create Account + Contact from the opportunity details
 *     Matching precedence: email before phone, newest record first.
 *  2. Account record type follows the opportunity record type (Retail/Wholesale).
 *  3. The price book is set from the record type; a mismatched account or price book is rejected.
 *  4. The resolved contact is added as the primary Opportunity Contact Role.
 */
public with sharing class OpportunityCustomerService {
    private static final Integer MAX_LEADS_PER_CONVERT = 100;

    public static void beforeInsert(List<Opportunity> opportunities) {
        resolveCustomers(opportunities);
        applyChannelRules(opportunities, null);
    }

    public static void beforeUpdate(List<Opportunity> opportunities, Map<Id, Opportunity> oldMap) {
        List<Opportunity> unresolved = new List<Opportunity>();
        for (Opportunity opp : opportunities) {
            if (opp.AccountId == null) {
                unresolved.add(opp);
            }
        }
        resolveCustomers(unresolved);
        applyChannelRules(opportunities, oldMap);
    }

    public static void afterSave(List<Opportunity> opportunities, Map<Id, Opportunity> oldMap) {
        Map<Id, Id> contactByOpportunity = new Map<Id, Id>();
        for (Opportunity opp : opportunities) {
            Opportunity old = oldMap == null ? null : oldMap.get(opp.Id);
            if (opp.Customer_Contact__c != null && (old == null || old.Customer_Contact__c != opp.Customer_Contact__c)) {
                contactByOpportunity.put(opp.Id, opp.Customer_Contact__c);
            }
        }
        if (contactByOpportunity.isEmpty()) {
            return;
        }
        Set<String> existingRoles = new Set<String>();
        for (OpportunityContactRole role : [
            SELECT OpportunityId, ContactId
            FROM OpportunityContactRole
            WHERE OpportunityId IN :contactByOpportunity.keySet()
        ]) {
            existingRoles.add(role.OpportunityId + '|' + role.ContactId);
        }
        List<OpportunityContactRole> roles = new List<OpportunityContactRole>();
        for (Id oppId : contactByOpportunity.keySet()) {
            Id contactId = contactByOpportunity.get(oppId);
            if (!existingRoles.contains(oppId + '|' + contactId)) {
                roles.add(new OpportunityContactRole(OpportunityId = oppId, ContactId = contactId, IsPrimary = true, Role = 'Decision Maker'));
            }
        }
        insert roles;
    }

    // ------------------------------------------------------------------ customer resolution

    private static void resolveCustomers(List<Opportunity> opportunities) {
        List<Opportunity> pending = new List<Opportunity>();
        Set<String> emails = new Set<String>();
        Set<String> phones = new Set<String>();
        for (Opportunity opp : opportunities) {
            if (opp.AccountId != null) {
                continue;
            }
            String email = normalizeEmail(opp.Customer_Email__c);
            String phone = normalizePhone(opp.Customer_Phone__c);
            if (email == null && phone == null) {
                opp.addError('Select an Account, or enter the Customer Email or Customer Phone so the customer can be found or created.');
                continue;
            }
            pending.add(opp);
            if (email != null) {
                emails.add(email);
            }
            if (phone != null) {
                phones.addAll(phoneSearchValues(opp.Customer_Phone__c));
            }
        }
        if (pending.isEmpty()) {
            return;
        }

        Map<String, SObject> contactByEmail = new Map<String, SObject>();
        Map<String, SObject> contactByPhone = new Map<String, SObject>();
        for (Contact c : [
            SELECT Id, AccountId, Email, Phone, MobilePhone
            FROM Contact
            WHERE AccountId != NULL AND (Email IN :emails OR Phone IN :phones OR MobilePhone IN :phones)
            ORDER BY CreatedDate DESC
        ]) {
            putIfAbsent(contactByEmail, normalizeEmail(c.Email), c);
            putIfAbsent(contactByPhone, normalizePhone(c.Phone), c);
            putIfAbsent(contactByPhone, normalizePhone(c.MobilePhone), c);
        }

        Map<String, SObject> leadByEmail = new Map<String, SObject>();
        Map<String, SObject> leadByPhone = new Map<String, SObject>();
        for (Lead l : [
            SELECT Id, OwnerId, Email, Phone, MobilePhone
            FROM Lead
            WHERE IsConverted = FALSE AND (Email IN :emails OR Phone IN :phones OR MobilePhone IN :phones)
            ORDER BY CreatedDate DESC
        ]) {
            putIfAbsent(leadByEmail, normalizeEmail(l.Email), l);
            putIfAbsent(leadByPhone, normalizePhone(l.Phone), l);
            putIfAbsent(leadByPhone, normalizePhone(l.MobilePhone), l);
        }

        Map<Id, List<Opportunity>> opportunitiesByLead = new Map<Id, List<Opportunity>>();
        Map<Id, Lead> leadsToConvert = new Map<Id, Lead>();
        List<Opportunity> needNewCustomer = new List<Opportunity>();
        for (Opportunity opp : pending) {
            String email = normalizeEmail(opp.Customer_Email__c);
            String phone = normalizePhone(opp.Customer_Phone__c);
            Contact contact = (Contact) firstMatch(contactByEmail, contactByPhone, email, phone);
            if (contact != null) {
                opp.AccountId = contact.AccountId;
                opp.Customer_Contact__c = contact.Id;
                continue;
            }
            Lead lead = (Lead) firstMatch(leadByEmail, leadByPhone, email, phone);
            if (lead != null) {
                if (!opportunitiesByLead.containsKey(lead.Id)) {
                    opportunitiesByLead.put(lead.Id, new List<Opportunity>());
                    leadsToConvert.put(lead.Id, lead);
                }
                opportunitiesByLead.get(lead.Id).add(opp);
                continue;
            }
            needNewCustomer.add(opp);
        }

        convertLeads(leadsToConvert, opportunitiesByLead);
        createCustomers(needNewCustomer);
    }

    private static void convertLeads(Map<Id, Lead> leads, Map<Id, List<Opportunity>> opportunitiesByLead) {
        if (leads.isEmpty()) {
            return;
        }
        String convertedStatus = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = TRUE ORDER BY SortOrder LIMIT 1].MasterLabel;
        List<Database.LeadConvert> requests = new List<Database.LeadConvert>();
        for (Lead lead : leads.values()) {
            Database.LeadConvert request = new Database.LeadConvert();
            request.setLeadId(lead.Id);
            request.setConvertedStatus(convertedStatus);
            request.setDoNotCreateOpportunity(true);
            // A queue cannot own accounts and contacts; the rep processing the opportunity takes the customer.
            if (lead.OwnerId.getSObjectType() != User.SObjectType) {
                request.setOwnerId(UserInfo.getUserId());
            }
            requests.add(request);
        }

        List<Database.LeadConvertResult> results = new List<Database.LeadConvertResult>();
        for (Integer i = 0; i < requests.size(); i += MAX_LEADS_PER_CONVERT) {
            List<Database.LeadConvert> chunk = new List<Database.LeadConvert>();
            for (Integer j = i; j < Math.min(i + MAX_LEADS_PER_CONVERT, requests.size()); j++) {
                chunk.add(requests[j]);
            }
            results.addAll(Database.convertLead(chunk, false));
        }

        // Lead conversion creates accounts with the user's default record type; align them with the channel.
        List<Account> accountsToRetype = new List<Account>();
        for (Integer i = 0; i < results.size(); i++) {
            Database.LeadConvertResult result = results[i];
            List<Opportunity> opps = opportunitiesByLead.get(requests[i].getLeadId());
            if (!result.isSuccess()) {
                for (Opportunity opp : opps) {
                    opp.addError('The matching lead could not be converted: ' + firstError(result.getErrors()));
                }
                continue;
            }
            for (Opportunity opp : opps) {
                opp.AccountId = result.getAccountId();
                opp.Customer_Contact__c = result.getContactId();
            }
            String channel = BlushConstants.channelOrDefault(Opportunity.SObjectType, opps[0].RecordTypeId);
            accountsToRetype.add(new Account(Id = result.getAccountId(), RecordTypeId = BlushConstants.recordTypeId(Account.SObjectType, channel)));
        }
        update accountsToRetype;
    }

    private static void createCustomers(List<Opportunity> opportunities) {
        List<Opportunity> creatable = new List<Opportunity>();
        List<Account> accounts = new List<Account>();
        for (Opportunity opp : opportunities) {
            if (String.isBlank(opp.Customer_Name__c)) {
                opp.addError('Customer Name is required to create a new customer.');
                continue;
            }
            String channel = BlushConstants.channelOrDefault(Opportunity.SObjectType, opp.RecordTypeId);
            String accountName = channel == BlushConstants.CHANNEL_WHOLESALE && String.isNotBlank(opp.Company_Name__c)
                ? opp.Company_Name__c
                : opp.Customer_Name__c;
            accounts.add(
                new Account(Name = accountName.trim(), Phone = opp.Customer_Phone__c, RecordTypeId = BlushConstants.recordTypeId(Account.SObjectType, channel))
            );
            creatable.add(opp);
        }
        if (accounts.isEmpty()) {
            return;
        }
        insert accounts;

        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < creatable.size(); i++) {
            Opportunity opp = creatable[i];
            String fullName = opp.Customer_Name__c.trim();
            Integer lastSpace = fullName.lastIndexOf(' ');
            contacts.add(
                new Contact(
                    AccountId = accounts[i].Id,
                    FirstName = lastSpace > 0 ? fullName.substring(0, lastSpace) : null,
                    LastName = lastSpace > 0 ? fullName.substring(lastSpace + 1) : fullName,
                    Email = opp.Customer_Email__c,
                    Phone = opp.Customer_Phone__c
                )
            );
        }
        insert contacts;
        for (Integer i = 0; i < creatable.size(); i++) {
            creatable[i].AccountId = accounts[i].Id;
            creatable[i].Customer_Contact__c = contacts[i].Id;
        }
    }

    // ------------------------------------------------------------------ channel rules

    private static void applyChannelRules(List<Opportunity> opportunities, Map<Id, Opportunity> oldMap) {
        Set<Id> accountIds = new Set<Id>();
        for (Opportunity opp : opportunities) {
            if (opp.AccountId != null) {
                accountIds.add(opp.AccountId);
            }
        }
        Map<Id, Account> accounts = new Map<Id, Account>([SELECT Id, RecordTypeId FROM Account WHERE Id IN :accountIds]);

        for (Opportunity opp : opportunities) {
            if (opp.hasErrors()) {
                continue;
            }
            String channel = BlushConstants.channelOrDefault(Opportunity.SObjectType, opp.RecordTypeId);
            Account acc = accounts.get(opp.AccountId);
            String accountChannel = acc == null ? null : BlushConstants.channelFor(Account.SObjectType, acc.RecordTypeId);
            if (accountChannel != null && accountChannel != channel) {
                opp.addError('A ' + channel + ' opportunity must be linked to a ' + channel + ' account. The selected account is ' + accountChannel + '.');
                continue;
            }

            Id expectedPricebook = PricebookService.getChannelPricebookId(channel);
            if (expectedPricebook == null) {
                opp.addError('The price book "' + PricebookService.pricebookName(channel) + '" is missing or inactive. Ask an administrator to set it up.');
                continue;
            }
            Opportunity old = oldMap == null ? null : oldMap.get(opp.Id);
            Boolean recordTypeChanged = old != null && old.RecordTypeId != opp.RecordTypeId;
            if (opp.Pricebook2Id == null || (recordTypeChanged && opp.Pricebook2Id == old.Pricebook2Id)) {
                opp.Pricebook2Id = expectedPricebook;
            } else if (opp.Pricebook2Id != expectedPricebook) {
                opp.addError(channel + ' opportunities must use the "' + PricebookService.pricebookName(channel) + '".');
            }
        }
    }

    // ------------------------------------------------------------------ helpers

    @TestVisible
    private static String normalizeEmail(String email) {
        return String.isBlank(email) ? null : email.trim().toLowerCase();
    }

    /** Compares phones on their last 10 digits so "+91 98765-43210" matches "9876543210". */
    @TestVisible
    private static String normalizePhone(String phone) {
        if (String.isBlank(phone)) {
            return null;
        }
        String digits = phone.replaceAll('[^0-9]', '');
        if (digits.length() < 6) {
            return null;
        }
        return digits.length() > 10 ? digits.right(10) : digits;
    }

    /** SOQL matches stored text exactly, so search the common ways a phone number is typed. */
    private static Set<String> phoneSearchValues(String phone) {
        String digits = normalizePhone(phone);
        return new Set<String>{ phone.trim(), digits, '+91' + digits, '+91 ' + digits, '0' + digits };
    }

    private static void putIfAbsent(Map<String, SObject> target, String key, SObject record) {
        if (key != null && !target.containsKey(key)) {
            target.put(key, record);
        }
    }

    private static SObject firstMatch(Map<String, SObject> byEmail, Map<String, SObject> byPhone, String email, String phone) {
        if (email != null && byEmail.containsKey(email)) {
            return byEmail.get(email);
        }
        if (phone != null && byPhone.containsKey(phone)) {
            return byPhone.get(phone);
        }
        return null;
    }

    private static String firstError(List<Database.Error> errors) {
        return errors == null || errors.isEmpty() ? 'Unknown error' : errors[0].getMessage();
    }
}