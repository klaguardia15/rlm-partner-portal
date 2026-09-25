@isTest
private class RLM_PartnerAgreementsTest {
    @isTest
    static void returnsCatalogWithoutError() {
        Test.startTest();
        List<RLM_PartnerAgreements.AgreementRow> agreements =
            RLM_PartnerAgreements.getAgreements();
        List<RLM_PartnerAgreements.PriceRow> prices =
            RLM_PartnerAgreements.getContractedPrices();
        Test.stopTest();
        System.assertNotEquals(null, agreements);
        System.assertNotEquals(null, prices);
    }

    @isTest
    static void detailRequiresValidId() {
        Test.startTest();
        RLM_PartnerAgreements.AgreementDetail blank =
            RLM_PartnerAgreements.getAgreementDetail(null);
        RLM_PartnerAgreements.AgreementDetail missing =
            RLM_PartnerAgreements.getAgreementDetail('001000000000001AAA');
        Test.stopTest();
        System.assertEquals(null, blank);
        System.assertEquals(null, missing);
    }

    @isTest
    static void detailRejectsGarbageId() {
        Boolean threw = false;
        try {
            RLM_PartnerAgreements.getAgreementDetail('not-an-id');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Expected AuraHandledException for a garbage Id');
    }

    @isTest
    static void overlayOrderActualsNoopsOnEmpty() {
        RLM_PartnerAgreements.overlayOrderActuals(null);
        RLM_PartnerAgreements.overlayOrderActuals(
            new List<RLM_PartnerAgreements.AgreementRow>()
        );
        RLM_PartnerAgreements.AgreementRow row =
            new RLM_PartnerAgreements.AgreementRow();
        row.actualAmount = 0;
        RLM_PartnerAgreements.overlayOrderActuals(
            new List<RLM_PartnerAgreements.AgreementRow>{ row }
        );
        System.assertEquals(0, row.actualAmount);
    }

    @isTest
    static void pulseReturnsEmptyWithoutPartnerAccount() {
        Test.startTest();
        RLM_PartnerAgreements.Pulse pulse = RLM_PartnerAgreements.getPulse();
        Test.stopTest();
        System.assertNotEquals(null, pulse);
        System.assertNotEquals(null, pulse.recentOrders);
        System.assertNotEquals(null, pulse.agreements);
        System.assertNotEquals(null, pulse.openQuotes);
    }

    @isTest
    static void callOffRequiresValidInput() {
        Test.startTest();
        Boolean badId = false;
        try {
            RLM_PartnerAgreements.getCallOffLines('not-an-id', Date.today());
        } catch (AuraHandledException e) {
            badId = true;
        }
        Boolean emptySchedules = false;
        try {
            RLM_PartnerAgreements.createCallOff(
                '001000000000001AAA',
                Date.today(),
                new List<RLM_PartnerAgreements.CallOffSelection>()
            );
        } catch (AuraHandledException e) {
            emptySchedules = true;
        }
        Test.stopTest();
        System.assertEquals(true, badId);
        System.assertEquals(true, emptySchedules);
    }

    @isTest
    static void groupsKitChildrenUnderParent() {
        RLM_PartnerAgreements.CallOffLine kit =
            new RLM_PartnerAgreements.CallOffLine();
        kit.id = '001000000000001AAA';
        kit.productId = '01t000000000001AAA';
        kit.productName = 'TC53 Hardware Kit (qty)';
        kit.plannedQuantity = 50;
        kit.salesPrice = 0;

        RLM_PartnerAgreements.CallOffLine computer =
            new RLM_PartnerAgreements.CallOffLine();
        computer.id = '001000000000002AAA';
        computer.productId = '01t000000000002AAA';
        computer.productName = 'TC53 Mobile Computer';
        computer.plannedQuantity = 50;
        computer.salesPrice = 1895;

        RLM_PartnerAgreements.CallOffLine cradle =
            new RLM_PartnerAgreements.CallOffLine();
        cradle.id = '001000000000003AAA';
        cradle.productId = '01t000000000003AAA';
        cradle.productName = 'TC53 ShareCradle Kit';
        cradle.plannedQuantity = 50;
        cradle.salesPrice = 177;

        List<RLM_PartnerAgreements.CallOffLine> lines =
            new List<RLM_PartnerAgreements.CallOffLine>{ kit, computer, cradle };
        Map<Id, Id> parentByChild = new Map<Id, Id>();
        Map<Id, Decimal> ratioByChild = new Map<Id, Decimal>();
        RLM_PartnerAgreements.applyKitNameFallback(lines, parentByChild, ratioByChild);
        List<RLM_PartnerAgreements.CallOffGroup> groups =
            RLM_PartnerAgreements.groupCallOffLines(lines, parentByChild, ratioByChild);

        System.assertEquals(1, groups.size());
        System.assertEquals(true, groups[0].isKit);
        System.assertEquals(3, groups[0].lines.size());
        System.assertEquals(true, groups[0].lines[0].isParent);
        System.assertEquals(false, groups[0].lines[1].isParent);
        System.assertEquals(1, groups[0].lines[1].childRatio);
    }

    @isTest
    static void refreshActualsJobConstructs() {
        RLM_PartnerAgreements.RefreshActualsJob job =
            new RLM_PartnerAgreements.RefreshActualsJob(
                UserInfo.getUserId(),
                UserInfo.getUserId()
            );
        System.assertNotEquals(null, job);
    }

    @isTest
    static void quoteSummaryRejectsGarbageId() {
        Boolean threw = false;
        try {
            RLM_PartnerAgreements.getQuoteSummary('not-an-id');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assertEquals(true, threw);
    }

    @isTest
    static void quoteSummaryAndConcession() {
        Id pbId = Test.getStandardPricebookId();
        Account acct = new Account(Name = 'Partner Account');
        insert acct;
        Opportunity opp = new Opportunity(
            Name = 'Portal WFK',
            AccountId = acct.Id,
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = pbId
        );
        insert opp;
        Product2 kit = new Product2(
            Name = 'Warehouse Frontline Kit',
            StockKeepingUnit = 'KIT-PARENT-T' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
            IsActive = true
        );
        Product2 tc53 = new Product2(
            Name = 'TC53 Mobile Computer',
            StockKeepingUnit = 'DEVICE-T' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
            IsActive = true
        );
        insert new List<Product2>{ kit, tc53 };
        insert new List<PricebookEntry>{
            new PricebookEntry(Pricebook2Id = pbId, Product2Id = kit.Id, UnitPrice = 0, IsActive = true),
            new PricebookEntry(Pricebook2Id = pbId, Product2Id = tc53.Id, UnitPrice = 1895, IsActive = true)
        };
        Quote q = new Quote(
            Name = 'Partner configure quote',
            OpportunityId = opp.Id,
            Pricebook2Id = pbId,
            Status = 'Draft'
        );
        insert q;
        PricebookEntry kitPbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :kit.Id LIMIT 1];
        PricebookEntry tc53Pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :tc53.Id LIMIT 1];
        insert new List<QuoteLineItem>{
            new QuoteLineItem(QuoteId = q.Id, PricebookEntryId = kitPbe.Id, Quantity = 10, UnitPrice = 0, Product2Id = kit.Id),
            new QuoteLineItem(
                QuoteId = q.Id, PricebookEntryId = tc53Pbe.Id, Quantity = 10, UnitPrice = 1895, Product2Id = tc53.Id
            )
        };

        Test.startTest();
        RLM_PartnerAgreements.QuoteSummary summary =
            RLM_PartnerAgreements.getQuoteSummary(String.valueOf(q.Id));
        RLM_PartnerAgreements.ConcessionResult tooShort =
            RLM_PartnerAgreements.requestPriceConcession(String.valueOf(q.Id), 'n/a');
        RLM_PartnerAgreements.ConcessionResult ok =
            RLM_PartnerAgreements.requestPriceConcession(
                String.valueOf(q.Id),
                'Need 18% off this Warehouse Frontline Kit for a 10-device refresh. Combined kit is not on the run-rate agreement.'
            );
        Test.stopTest();

        System.assertEquals(q.Id, summary.id);
        System.assertEquals('Partner Account', summary.accountName);
        System.assertEquals('Warehouse Frontline Kit', summary.solutionName);
        System.assertEquals(true, summary.catalogs.size() >= 1);
        for (RLM_PartnerAgreements.CatalogRow catalog : summary.catalogs) {
            System.assert(String.isNotBlank(catalog.name), catalog.name);
        }
        System.assertEquals(false, tooShort.isSuccess);
        System.assertEquals(true, ok.isSuccess, 'concession: ' + ok.errorMessage);
        Quote stamped = [
            SELECT RLM_Partner_Request__c, RLM_Deal_Motion__c, RLM_PC_Justification__c
            FROM Quote WHERE Id = :q.Id
        ];
        System.assertEquals(true, stamped.RLM_Partner_Request__c);
        System.assertEquals('Quote_To_Order', stamped.RLM_Deal_Motion__c);
        System.assert(stamped.RLM_PC_Justification__c.contains('18%'));
        if (ok.taskId != null) {
            Task job = [SELECT Subject, WhatId, OwnerId FROM Task WHERE Id = :ok.taskId];
            System.assertEquals(q.Id, job.WhatId);
            System.assert(job.Subject.contains('Partner Account'), job.Subject);
        }
    }

    @isTest
    static void parentQuantityScalesChildren() {
        Id pbId = Test.getStandardPricebookId();
        Account acct = new Account(Name = 'Partner Account');
        insert acct;
        Opportunity opp = new Opportunity(
            Name = 'Qty scale',
            AccountId = acct.Id,
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = pbId
        );
        insert opp;
        Product2 kit = new Product2(
            Name = 'Warehouse Frontline Kit',
            StockKeepingUnit = 'KIT-PARENT-Q' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
            IsActive = true
        );
        Product2 child = new Product2(
            Name = 'TC53 Mobile Computer',
            StockKeepingUnit = 'DEVICE-Q' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
            IsActive = true
        );
        insert new List<Product2>{ kit, child };
        insert new List<PricebookEntry>{
            new PricebookEntry(Pricebook2Id = pbId, Product2Id = kit.Id, UnitPrice = 0, IsActive = true),
            new PricebookEntry(Pricebook2Id = pbId, Product2Id = child.Id, UnitPrice = 1895, IsActive = true)
        };
        Quote q = new Quote(
            Name = 'Qty scale quote',
            OpportunityId = opp.Id,
            Pricebook2Id = pbId,
            Status = 'Draft'
        );
        insert q;
        PricebookEntry kitPbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :kit.Id LIMIT 1];
        PricebookEntry childPbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :child.Id LIMIT 1];
        QuoteLineItem parentLine = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = kitPbe.Id,
            Quantity = 1,
            UnitPrice = 0,
            Product2Id = kit.Id
        );
        insert parentLine;
        QuoteLineItem sibling = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = childPbe.Id,
            Quantity = 1,
            UnitPrice = 1895,
            Product2Id = child.Id
        );
        insert sibling;

        Test.startTest();
        RLM_PartnerAgreements.QtyResult result =
            RLM_PartnerAgreements.updateParentQuantity(
                String.valueOf(q.Id),
                String.valueOf(parentLine.Id),
                10
            );
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'qty: ' + result.errorMessage);
        QuoteLineItem parentAfter = [SELECT Quantity FROM QuoteLineItem WHERE Id = :parentLine.Id];
        QuoteLineItem siblingAfter = [SELECT Quantity FROM QuoteLineItem WHERE Id = :sibling.Id];
        System.assertEquals(10, parentAfter.Quantity);
        System.assertEquals(1, siblingAfter.Quantity);
    }
}
