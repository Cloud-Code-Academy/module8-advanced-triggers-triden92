public with sharing class OpportunityHelper extends TriggerHandler{
    private List<Opportunity> newOppList;
    private List<Opportunity> oldOppList;
    private Map<Id,Opportunity> newOppMap;
    private Map<Id,Opportunity> oldOppMap;
    
    public OpportunityHelper() {
        this.newOppList = (List<Opportunity>)Trigger.new;
        this.oldOppList = (List<Opportunity>)Trigger.old;
        this.newOppMap = (Map<Id,Opportunity>)Trigger.newMap;
        this.oldOppMap = (Map<Id,Opportunity>)Trigger.oldMap;

    }

    public override void beforeInsert(){
        setDefaultTypeForNewOpps(newOppList);
    }

    public override void afterInsert(){
        List<Task> insertTaskList = createTaskOnNewOpps(newOppList);

        Database.insert(insertTaskList);
    }
    
    public override void beforeUpdate(){
        opportunityAmountValidation(newOppList);
        setOpportunityPrimaryContact(newOppList);
        appendStagesInOppDescription(newOppMap, oldOppMap);
    }

    public override void beforeDelete(){
        //This method is covered by the preventDeletionOfClosedOpps method
        //deleteClosedWonBankingOpportunityValidation(oldOppList);
        preventDeletionOfClosedOpps(oldOppList);
    }

    public override void afterDelete(){
        deletedOpportunityNotification(oldOppList);
    }

    public override void afterUndelete(){
        List<Opportunity> updateOppList = assignPrimaryContact(newOppMap);

        Database.update(updateOppList);
        
    }


    public static void opportunityAmountValidation(List<Opportunity> oppList){
        for(Opportunity eachOpp :oppList){
            if(eachOpp.Amount < 5000){
                eachOpp.addError('Opportunity amount must be greater than 5000');
            }
        }

    }

    // public static void deleteClosedWonBankingOpportunityValidation(List<Opportunity> oppList){
    //     for(Opportunity eachOpp :oppList){
    //         if(eachOpp.StageName == 'Closed Won'){
    //             eachOpp.addError('Cannot delete closed opportunity for a banking account that is won');
    //         }
    //     }
            
    // }

    public static void setOpportunityPrimaryContact(List<Opportunity> oppList){
        List<Id> accIdList = new List<Id>();
        for(Opportunity eachOpp :oppList){
            accIdList.add(eachOpp.AccountId);
        }

        Map<Id,Id> contactsByAccountIdMap = new Map<Id,Id>();
        List<Contact> contactList = [SELECT Id,AccountId FROM Contact WHERE AccountId IN :accIdList AND Title = 'CEO'];
        for(Contact eachContact :contactList){
            contactsByAccountIdMap.put(eachContact.AccountId,eachContact.Id);
        }
        
        for(Opportunity eachOpp :oppList){
            if(contactsByAccountIdMap.containsKey(eachOpp.AccountId)){
                eachOpp.Primary_Contact__c = contactsByAccountIdMap.get(eachOpp.AccountId);
            }
        }

        
    }
    public static void setDefaultTypeForNewOpps(List<Opportunity> oppList){
        for(Opportunity eachOpp :oppList){
            if(eachOpp.Type == null){
                eachOpp.Type = 'New Customer';
            }
        }

    }
    public static void preventDeletionOfClosedOpps(List<Opportunity> oppList){
        for(Opportunity eachOpp :oppList){
            if(eachOpp.IsClosed == true){
                eachOpp.addError('Cannot delete closed opportunity');
            }
        }
    }
    public static List<Task> createTaskOnNewOpps (List<Opportunity> oppList){
        List<Task> insertTaskList = new List<Task>();
        for(Opportunity eachOpp :oppList){
            Task tsk = new Task();
            tsk.Subject = 'Call Primary Contact';
            tsk.WhatId = eachOpp.Id;
            tsk.WhoId = eachOpp.Primary_Contact__c;
            tsk.OwnerId = eachOpp.OwnerId;
            tsk.ActivityDate = Date.today().addDays(3);
            insertTaskList.add(tsk);
        }
        return insertTaskList;
    }

    public static List<Opportunity> appendStagesInOppDescription(Map<Id,Opportunity> oppNewMap, Map<Id,Opportunity> oppOldMap){
        List<Opportunity> updateOppList = new List<Opportunity>();
        for(Opportunity eachOpp :oppNewMap.values()){
          Opportunity newRecord = oppNewMap.get(eachOpp.Id);
          Opportunity oldRecord = oppOldMap.get(eachOpp.Id);
            if(newRecord.StageName != oldRecord.StageName){
                newRecord.Description += '\n Stage Change:' + newRecord.StageName + ':' + DateTime.now().format();
                updateOppList.add(newRecord);
            }
        }
        return updateOppList;
    }

    public static void deletedOpportunityNotification(List<Opportunity> oppList){
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        List<String> ownerIdList = new List<String>();
        for(Opportunity eachOpp :oppList){
            ownerIdList.add(eachOpp.OwnerId);
        }
        List<User> ownerUserList = [SELECT Id, Email FROM User WHERE Id IN :ownerIdList];
        Map<Id,String> ownerEmailByUserId = new Map<Id,String>();
        for(User owner :ownerUserList){
            ownerEmailByUserId.put(owner.Id, owner.Email);
        }
        Map<Id,String> ownerEmailByOppIdMap = new Map<Id,String>();
        for(Opportunity eachOpp :oppList){
           if(ownerEmailByUserId.containsKey(eachOpp.OwnerId)){
                ownerEmailByOppIdMap.put(eachOpp.Id, ownerEmailByUserId.get(eachOpp.OwnerId));
           }
        }
        for (Opportunity opp : oppList){
            if(ownerEmailByOppIdMap.containsKey(opp.Id)){
                List<String> toAddresses = new List<String>();
                toAddresses.add(ownerEmailByOppIdMap.get(opp.Id));
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(toAddresses);
                mail.setSubject('Opportunity Deleted : ' + opp.Name);
                mail.setPlainTextBody('Your Opportunity: ' + opp.Name +' has been deleted.');
                mails.add(mail);
                }
            
        }        
        
        try {
            Messaging.sendEmail(mails);
        } catch (Exception e){
            System.debug('Exception: ' + e.getMessage());
        }
    }

    private static List<Opportunity> assignPrimaryContact(Map<Id,Opportunity> oppNewMap) {        
        Map<Id,Opportunity> undeletedOppsByIdMap = new Map<Id,Opportunity>();
        List<Opportunity> undeletedOppsList = [SELECT Id,AccountId,Primary_Contact__c FROM Opportunity WHERE Id IN :oppNewMap.keySet()];
        for(Opportunity eachOpp :undeletedOppsList){
            undeletedOppsByIdMap.put(eachOpp.Id,eachOpp);
            
        }
        List<Id> accIdList = new List<Id>();
        List<Opportunity> updatedOppList = new List<Opportunity>();
        for(Opportunity eachOpp :undeletedOppsByIdMap.values()){
            accIdList.add(eachOpp.AccountId);
            
        }

        Map<Id,Id> contactsByAccountIdMap = new Map<Id,Id>();
        List<Contact> contactList = [SELECT Id,AccountId FROM Contact WHERE AccountId IN :accIdList AND Title = 'VP Sales'];
        for(Contact eachContact :contactList){
            contactsByAccountIdMap.put(eachContact.AccountId,eachContact.Id);
            
        }
        
        for(Opportunity eachOpp :undeletedOppsByIdMap.values()){
            if(contactsByAccountIdMap.containsKey(eachOpp.AccountId) && eachOpp.Primary_Contact__c == null){
                eachOpp.Primary_Contact__c = contactsByAccountIdMap.get(eachOpp.AccountId);
                updatedOppList.add(eachOpp);
               
                

            }
        }
        return updatedOppList;
        
        
    }

}

    
