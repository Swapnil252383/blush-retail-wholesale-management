// Creates one Sales user and one Marketing user for the Blush demo (uses 2 Salesforce licenses).
// Run: sf apex run --file scripts/apex/create-users.apex --target-org MyDevOrg
// Notification emails go to the running admin's email address.
String suffix = '@blush-' + UserInfo.getOrganizationId().left(15).toLowerCase() + '.demo';
String adminEmail = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()].Email;
Map<String, Id> profiles = new Map<String, Id>();
for (Profile p : [SELECT Id, Name FROM Profile WHERE Name IN ('Standard User', 'Marketing User')]) {
    profiles.put(p.Name, p.Id);
}

List<User> users = new List<User>();
if ([SELECT COUNT() FROM User WHERE Username = :('sneha.patil' + suffix)] == 0) {
    users.add(new User(
        FirstName = 'Sneha', LastName = 'Patil', Alias = 'spatil', Username = 'sneha.patil' + suffix, Email = adminEmail,
        ProfileId = profiles.get('Standard User'), TimeZoneSidKey = 'Asia/Kolkata', LocaleSidKey = 'en_IN',
        EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US', Title = 'Sales Representative'
    ));
}
if ([SELECT COUNT() FROM User WHERE Username = :('neha.kulkarni' + suffix)] == 0) {
    users.add(new User(
        FirstName = 'Neha', LastName = 'Kulkarni', Alias = 'nkulk', Username = 'neha.kulkarni' + suffix, Email = adminEmail,
        ProfileId = profiles.get('Marketing User'), UserPermissionsMarketingUser = true, TimeZoneSidKey = 'Asia/Kolkata',
        LocaleSidKey = 'en_IN', EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US', Title = 'Marketing Executive'
    ));
}
// Partial success: a Developer Edition org may not have a free license for every user.
List<User> created = new List<User>();
List<Database.SaveResult> results = Database.insert(users, false);
for (Integer i = 0; i < results.size(); i++) {
    if (results[i].isSuccess()) {
        created.add(users[i]);
    } else {
        System.debug(LoggingLevel.ERROR, 'Could not create ' + users[i].Username + ': ' + results[i].getErrors()[0].getMessage());
    }
}
users = created;

Map<String, Id> permissionSets = new Map<String, Id>();
for (PermissionSet ps : [SELECT Id, Name FROM PermissionSet WHERE Name IN ('Blush_Sales_User', 'Blush_Marketing_User')]) {
    permissionSets.put(ps.Name, ps.Id);
}
List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
for (User u : users) {
    String permissionSet = u.LastName == 'Patil' ? 'Blush_Sales_User' : 'Blush_Marketing_User';
    assignments.add(new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = permissionSets.get(permissionSet)));
}
insert assignments;
System.debug('Created users: ' + users.size());
