/**
 * Partner Central: start a Configure and Quote request for the partner account.
 * Creates Opportunity + Quote because Partner Community users cannot use
 * list-view New (Opportunity create is not on the partner license path).
 */
public with sharing class RLM_PartnerStartQuote {

    @TestVisible
    static Id testAccountId;

    public class StartResult {
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Id quoteId;
        @AuraEnabled public String quoteName;
    }

    public class StartInput {
        @InvocableVariable(label='Quote Name')
        public String quoteName;
    }

    public class StartOutput {
        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;
        @InvocableVariable(label='Error Message')
        public String errorMessage;
        @InvocableVariable(label='Quote Id')
        public Id quoteId;
    }

    @AuraEnabled
    public static StartResult startConfigureQuote(String quoteName) {
        StartResult out = new StartResult();
        out.isSuccess = false;
        try {
            out = new Writer().create(quoteName);
        } catch (Exception e) {
            out.isSuccess = false;
            out.errorMessage = e.getMessage();
        }
        return out;
    }

    @InvocableMethod(
        label='Start Partner Configure Quote'
        description='Creates a Draft quote-to-order Quote on the partner account and returns the Quote Id.'
    )
    public static List<StartOutput> startConfigureQuoteInvocable(List<StartInput> inputs) {
        List<StartOutput> rows = new List<StartOutput>();
        if (inputs == null) {
            return rows;
        }
        for (StartInput input : inputs) {
            StartOutput row = new StartOutput();
            StartResult innerResult = startConfigureQuote(input == null ? null : input.quoteName);
            row.isSuccess = innerResult.isSuccess;
            row.errorMessage = innerResult.errorMessage;
            row.quoteId = innerResult.quoteId;
            rows.add(row);
        }
        return rows;
    }

    private without sharing class Writer {
        public StartResult create(String quoteName) {
            StartResult out = new StartResult();
            out.isSuccess = false;
            Id accountId = resolveAccountId();
            if (accountId == null) {
                out.errorMessage = 'No partner account on this user. Sign in as the partner user.';
                return out;
            }
            String name = String.isBlank(quoteName) ? 'Partner quote' : quoteName.trim();
            Id pricebookId = standardPricebookId();
            Opportunity opp = new Opportunity(
                Name = name,
                AccountId = accountId,
                StageName = 'Qualification',
                CloseDate = Date.today().addDays(30),
                Pricebook2Id = pricebookId
            );
            insert opp;
            Quote quote = new Quote(
                Name = name,
                OpportunityId = opp.Id,
                Pricebook2Id = pricebookId,
                Status = 'Draft',
                RLM_Deal_Motion__c = 'Quote_To_Order',
                RLM_Partner_Request__c = true
            );
            insert quote;
            out.isSuccess = true;
            out.quoteId = quote.Id;
            out.quoteName = name;
            return out;
        }

        private Id resolveAccountId() {
            if (testAccountId != null) {
                return testAccountId;
            }
            List<User> users = [
                SELECT Contact.AccountId
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];
            if (users.isEmpty() || users[0].Contact == null) {
                return null;
            }
            return users[0].Contact.AccountId;
        }

        private Id standardPricebookId() {
            List<Pricebook2> books = [
                SELECT Id
                FROM Pricebook2
                WHERE IsStandard = true
                LIMIT 1
            ];
            return books.isEmpty() ? null : books[0].Id;
        }
    }
}
