@isTest
private class RLM_PartnerStartQuoteTest {

    @isTest
    static void startCreatesQuoteOnAccount() {
        Account acct = new Account(Name = 'Partner Account Start');
        insert acct;
        RLM_PartnerStartQuote.testAccountId = acct.Id;

        Test.startTest();
        RLM_PartnerStartQuote.StartResult result =
            RLM_PartnerStartQuote.startConfigureQuote('Partner configure quote');
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'start: ' + result.errorMessage);
        System.assertNotEquals(null, result.quoteId);
        Quote created = [
            SELECT Name, Status, Opportunity.AccountId, RLM_Partner_Request__c, RLM_Deal_Motion__c
            FROM Quote
            WHERE Id = :result.quoteId
        ];
        System.assertEquals('Partner configure quote', created.Name);
        System.assertEquals(acct.Id, created.Opportunity.AccountId);
        System.assertEquals(true, created.RLM_Partner_Request__c);
        System.assertEquals('Quote_To_Order', created.RLM_Deal_Motion__c);
    }

    @isTest
    static void missingAccountReturnsError() {
        RLM_PartnerStartQuote.testAccountId = null;
        Test.startTest();
        RLM_PartnerStartQuote.StartResult result =
            RLM_PartnerStartQuote.startConfigureQuote('x');
        Test.stopTest();
        System.assertEquals(false, result.isSuccess);
        System.assert(result.errorMessage.contains('partner account'), result.errorMessage);
    }
}
