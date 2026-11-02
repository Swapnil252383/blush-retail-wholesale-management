public class SetSkillsHandler {


    public static void afterInsert(List<Contact> newList) {
        Set<Id> accountIds = new Set<Id>();
        for (Contact c : newList) {
            if (c.AccountId != null) {
                accountIds.add(c.AccountId);
            }
        }
        SetSkillsHelper.updateAccountSkills(accountIds);
    }

    public static void afterUpdate(List<Contact> newList, Map<Id, Contact> oldMap) {
        Set<Id> accountIds = new Set<Id>();
        for (Contact c : newList) {
            Contact oldCon = oldMap.get(c.Id);

            Boolean skillsChanged  = c.Skills__c != oldCon.Skills__c;
            Boolean accountChanged = c.AccountId != oldCon.AccountId;

            if (skillsChanged || accountChanged) {
                if (c.AccountId != null) {
                    accountIds.add(c.AccountId);       
                }
                if (oldCon.AccountId != null) {
                    accountIds.add(oldCon.AccountId); 
                }
            }
        }
        SetSkillsHelper.updateAccountSkills(accountIds);
    }

  
    public static void afterDelete(List<Contact> oldList) {
        Set<Id> accountIds = new Set<Id>();
        for (Contact c : oldList) {
            if (c.AccountId != null) {
                accountIds.add(c.AccountId);
            }
        }
        SetSkillsHelper.updateAccountSkills(accountIds);
    }

    public static void afterUndelete(List<Contact> newList) {
        afterInsert(newList);   
    }
}