global with sharing class ContactSoapService {

    global class ContactDetails {
        webservice String contactId;
        webservice String firstName;
        webservice String lastName;
        webservice String email;
        webservice String phone;
        webservice String accountId;
    }

    webservice static ContactDetails getContactDetails(
        String contactId
    ) {
        Contact con = [
            SELECT Id, FirstName, LastName,
                   Email, Phone, AccountId
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];

        ContactDetails details = new ContactDetails();

        details.contactId = con.Id;
        details.firstName = con.FirstName;
        details.lastName = con.LastName;
        details.email = con.Email;
        details.phone = con.Phone;
        details.accountId = con.AccountId;

        return details;
    }
}