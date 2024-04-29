/*
AccountHelper Overview

The `AccountHelper` class is designed to provide helper methods that assist in performing specific operations on Account records. 
This class is intended to modularize the logic used in the `AccountTrigger` to ensure separation of concerns, improve readability, and ease maintenance. 

This class is currently stubbed out. As part of this exercise, you are expected to:
1. Implement the method bodies to carry out the specified operations on Account records.
2. Refactor the `AccountTrigger` to utilize the methods provided in this `AccountHelper` class.

Methods:
- `setTypeProspect(SObject objects)`: 
    - Purpose: Update the 'Type' field of the given Account record to 'Prospect' if it's not already set.
    - Note: You'll likely need to adjust the method signature to accept the necessary parameters.

- `addressCopy()`: 
    - Purpose: Copy the shipping address of the Account to its billing address. 
    - Note: You'll likely need to adjust the method signature to accept the necessary parameters.

- `setRating`: 
    - Purpose: Evaluate certain conditions on the Account and assign a rating based on that evaluation. You'll need to define the method's signature and implement its logic.

- `defaultContact`: 
    - Purpose: Create a default contact related to the Account after the Account is inserted. You'll need to define the method's signature and implement its logic.

Remember:
Always ensure that your helper methods are bulk-safe to handle multiple records efficiently. 
*/
public with sharing class AccountHelper extends TriggerHandler {
    
    private List<Account> newAccList;
    private Map<Id,Account> newAccMap;
    private List<Account> oldAccList;
    private Map<Id,Account> oldAccMap;

    public AccountHelper(){
        this.newAccList = (List<Account>)Trigger.new;
        this.newAccMap = (Map<Id,Account>)Trigger.newMap;
        this.oldAccList = (List<Account>)Trigger.old;
        this.oldAccMap = (Map<Id,Account>)Trigger.oldMap;

    }
    
    public override void beforeInsert(){
        setTypeProspect(newAccList);
        addressCopy(newAccList);
        setRating(newAccList);
            
    }
    
    public override void afterInsert(){
       List<Contact> insertContacts = defaultContact(newAccList);

       insert insertContacts;

            
    }

    public static void setTypeProspect(List<Account> accList){
        List<Account> accUpdateList = new List<Account>(); 
         for(Account acc :accList){
             if(acc.Type == null){
                 acc.Type = 'Prospect';
             }
             accUpdateList.add(acc);
         }
            
     }

     public static void  addressCopy(List<Account> accList){
        List<Account> accUpdateList = new List<Account>();
        for(Account acc :accList){
            acc.BillingStreet = acc.ShippingStreet ?? '';
            acc.BillingCity = acc.ShippingCity ?? '';
            acc.BillingState = acc.ShippingState ?? '';
            acc.BillingPostalCode = acc.ShippingPostalCode ?? '';
            acc.BillingCountry = acc.ShippingCountry ?? '';

            accUpdateList.add(acc);
        }
        
    }

    public static void setRating(List<Account> accList){
        List<Account> accUpdateList = new List<Account>();
        for(Account acc :accList){
            if(acc.Phone != '' && acc.Website != '' && acc.Fax != ''){
                acc.Rating = 'Hot';

                accUpdateList.add(acc);
            }
        }
        
    }

    public static List<Contact> defaultContact(List<Account> accList){
        Set<Contact> contactSet = new Set<Contact>();
        List<Contact> contactInsertList = new List<Contact>();

        for(Account acc :accList){
            Contact newContact = new Contact();
            newContact.LastName = 'DefaultContact';
            newContact.Email = 'default@email.com';
            newContact.AccountId = acc.Id;

            contactSet.add(newContact);

        }
        for(Contact eachContact :contactSet){
            contactInsertList.add(eachContact);
        }
        return contactInsertList;
    }
    
}
