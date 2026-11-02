public class SetSkillsHelper {

    public static void updateAccountSkills(Set<Id> accountIds) {

        if (accountIds == null || accountIds.isEmpty()) {
            return; 
        }


        Map<Id, Set<String>> skillsByAccount = new Map<Id, Set<String>>();
        for (Id accId : accountIds) {
            skillsByAccount.put(accId, new Set<String>());
        }

   
        for (Contact c : [SELECT AccountId, Skills__c
                          FROM Contact
                          WHERE AccountId IN :accountIds
                          AND Skills__c != null]) {

          
            for (String skill : c.Skills__c.split(';')) {
                if (String.isNotBlank(skill)) {
                 
                    skillsByAccount.get(c.AccountId).add(skill.trim());
                }
            }
        }

     
        List<Account> accountsToUpdate = new List<Account>();
        for (Id accId : skillsByAccount.keySet()) {
            List<String> skills = new List<String>(skillsByAccount.get(accId));
            skills.sort();  

            Account acc = new Account(Id = accId);
            acc.Skills__c = skills.isEmpty() ? null : String.join(skills, ';');
            accountsToUpdate.add(acc);
        }

     
        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
    }
}