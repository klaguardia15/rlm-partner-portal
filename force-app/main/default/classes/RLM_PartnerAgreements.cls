/**
 * Partner Central: agreements, call-off orders, and configure-and-quote.
 */
public with sharing class RLM_PartnerAgreements {
    public class AgreementRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String accountName;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public String scheduleFrequency;
        @AuraEnabled public Integer scheduleCount;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public Decimal actualAmount;
    }

    public class PriceRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String productName;
        @AuraEnabled public String sku;
        @AuraEnabled public Id agreementId;
        @AuraEnabled public String agreementName;
        @AuraEnabled public Decimal listPrice;
        @AuraEnabled public Decimal discountPercentage;
        @AuraEnabled public Decimal salesPrice;
        @AuraEnabled public Decimal plannedQuantity;
        @AuraEnabled public Decimal actualQuantity;
    }

    public class AgreementDetail {
        @AuraEnabled public AgreementRow agreement;
        @AuraEnabled public List<PriceRow> prices;
        @AuraEnabled public List<OrderRow> orders;
    }

    @AuraEnabled(cacheable=true)
    public static List<AgreementRow> getAgreements() {
        List<AgreementRow> rows = new List<AgreementRow>();
        for (SalesAgreement sa : [
            SELECT
                Id,
                Name,
                Status,
                Account.Name,
                StartDate,
                EndDate,
                ScheduleFrequency,
                ScheduleCount,
                TotalAgreementAmount,
                TotalActualAgreementAmount
            FROM SalesAgreement
            WITH USER_MODE
            ORDER BY StartDate DESC NULLS LAST, Name
            LIMIT 50
        ]) {
            rows.add(toAgreementRow(sa));
        }
        overlayOrderActuals(rows);
        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static List<PriceRow> getContractedPrices() {
        List<PriceRow> rows = new List<PriceRow>();
        for (SalesAgreementProduct sap : [
            SELECT
                Id,
                Name,
                ListPrice,
                DiscountPercentage,
                SalesPrice,
                InitialPlannedQuantity,
                TotalPlannedQuantity,
                TotalActualQuantity,
                SalesAgreementId,
                SalesAgreement.Name,
                Product.Name,
                Product.StockKeepingUnit
            FROM SalesAgreementProduct
            WITH USER_MODE
            ORDER BY SalesAgreement.Name, Name
            LIMIT 50
        ]) {
            rows.add(toPriceRow(sap));
        }
        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static AgreementDetail getAgreementDetail(String recordId) {
        if (String.isBlank(recordId)) {
            return null;
        }
        Id saId;
        try {
            saId = Id.valueOf(recordId);
        } catch (Exception e) {
            AuraHandledException ex = new AuraHandledException('Invalid sales agreement Id');
            ex.setMessage('Invalid sales agreement Id');
            throw ex;
        }

        List<SalesAgreement> matches = [
            SELECT
                Id,
                Name,
                Status,
                Account.Name,
                StartDate,
                EndDate,
                ScheduleFrequency,
                ScheduleCount,
                TotalAgreementAmount,
                TotalActualAgreementAmount
            FROM SalesAgreement
            WHERE Id = :saId
            WITH USER_MODE
            LIMIT 1
        ];
        if (matches.isEmpty()) {
            return null;
        }

        AgreementDetail detail = new AgreementDetail();
        detail.agreement = toAgreementRow(matches[0]);
        detail.prices = new List<PriceRow>();
        detail.orders = new List<OrderRow>();
        for (SalesAgreementProduct sap : [
            SELECT
                Id,
                Name,
                ListPrice,
                DiscountPercentage,
                SalesPrice,
                InitialPlannedQuantity,
                TotalPlannedQuantity,
                TotalActualQuantity,
                SalesAgreementId,
                SalesAgreement.Name,
                Product.Name,
                Product.StockKeepingUnit
            FROM SalesAgreementProduct
            WHERE SalesAgreementId = :saId
            WITH USER_MODE
            ORDER BY Name
            LIMIT 200
        ]) {
            detail.prices.add(toPriceRow(sap));
        }
        for (Order ord : [
            SELECT Id, OrderNumber, Status, EffectiveDate, TotalAmount
            FROM Order
            WHERE SalesAgreementId = :saId
            WITH USER_MODE
            ORDER BY EffectiveDate DESC, CreatedDate DESC
            LIMIT 50
        ]) {
            OrderRow row = new OrderRow();
            row.id = ord.Id;
            row.orderNumber = ord.OrderNumber;
            row.status = ord.Status;
            row.effectiveDate = ord.EffectiveDate;
            row.totalAmount = ord.TotalAmount;
            detail.orders.add(row);
        }
        overlayOrderActuals(new List<AgreementRow>{ detail.agreement });
        return detail;
    }

    public class OrderRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String orderNumber;
        @AuraEnabled public String status;
        @AuraEnabled public Date effectiveDate;
        @AuraEnabled public Decimal totalAmount;
    }

    public class QuoteRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal grandTotal;
        @AuraEnabled public Date createdDate;
        @AuraEnabled public Boolean partnerRequest;
    }

    public class CatalogRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String subtitle;
    }

    public class QuoteLineRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String groupName;
        @AuraEnabled public String productName;
        @AuraEnabled public String sku;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal listPrice;
        @AuraEnabled public Decimal netAmount;
        @AuraEnabled public Boolean isParent;
    }

    public class QuoteGroup {
        @AuraEnabled public String name;
        @AuraEnabled public List<QuoteLineRow> lines;
        @AuraEnabled public Decimal netAmount;
    }

    public class QuoteSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String quoteNumber;
        @AuraEnabled public String status;
        @AuraEnabled public String accountName;
        @AuraEnabled public String solutionName;
        @AuraEnabled public Date createdDate;
        @AuraEnabled public Decimal grandTotal;
        @AuraEnabled public Boolean partnerRequest;
        @AuraEnabled public String justification;
        @AuraEnabled public List<QuoteGroup> groups;
        @AuraEnabled public List<CatalogRow> catalogs;
        @AuraEnabled public String recommendedSku;
        @AuraEnabled public String recommendedName;
    }

    public class ConcessionResult {
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Id taskId;
        @AuraEnabled public String message;
    }

    public class QtyResult {
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Integer updatedCount;
    }

    public class ConcessionInput {
        @InvocableVariable(required=true label='Quote Id')
        public String quoteId;
        @InvocableVariable(required=true label='PC Justification')
        public String justification;
    }

    public class ConcessionOutput {
        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;
        @InvocableVariable(label='Error Message')
        public String errorMessage;
        @InvocableVariable(label='Task Id')
        public Id taskId;
        @InvocableVariable(label='Message')
        public String message;
    }

    public class Pulse {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public Decimal ytdOrderAmount;
        @AuraEnabled public Integer ytdOrderCount;
        @AuraEnabled public Integer activeAgreementCount;
        @AuraEnabled public Decimal contractedAmount;
        @AuraEnabled public Decimal actualAmount;
        @AuraEnabled public Integer openQuoteCount;
        @AuraEnabled public List<OrderRow> recentOrders;
        @AuraEnabled public List<AgreementRow> agreements;
        @AuraEnabled public List<QuoteRow> openQuotes;
    }

    @AuraEnabled(cacheable=true)
    public static Pulse getPulse() {
        Pulse pulse = new Pulse();
        pulse.ytdOrderAmount = 0;
        pulse.ytdOrderCount = 0;
        pulse.activeAgreementCount = 0;
        pulse.contractedAmount = 0;
        pulse.actualAmount = 0;
        pulse.openQuoteCount = 0;
        pulse.recentOrders = new List<OrderRow>();
        pulse.agreements = new List<AgreementRow>();
        pulse.openQuotes = new List<QuoteRow>();

        List<User> users = [
            SELECT Contact.AccountId, Contact.Account.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH USER_MODE
            LIMIT 1
        ];
        if (users.isEmpty() || users[0].Contact == null || users[0].Contact.AccountId == null) {
            return pulse;
        }
        Id accountId = users[0].Contact.AccountId;
        pulse.accountId = accountId;
        pulse.accountName = users[0].Contact.Account != null
            ? users[0].Contact.Account.Name
            : null;

        List<AgreementRow> agreements = getAgreements();
        pulse.agreements = agreements;
        for (AgreementRow row : agreements) {
            if (row.totalAmount != null) {
                pulse.contractedAmount += row.totalAmount;
            }
            if (row.actualAmount != null) {
                pulse.actualAmount += row.actualAmount;
            }
            if (row.status == 'Activated') {
                pulse.activeAgreementCount++;
            }
        }

        Date yearStart = Date.newInstance(Date.today().year(), 1, 1);
        Datetime yearStartDt = Datetime.newInstance(yearStart, Time.newInstance(0, 0, 0, 0));
        for (AggregateResult ar : [
            SELECT SUM(TotalAmount) amt, COUNT(Id) n
            FROM Order
            WHERE AccountId = :accountId AND CreatedDate >= :yearStartDt
            WITH USER_MODE
        ]) {
            Decimal amt = (Decimal) ar.get('amt');
            pulse.ytdOrderAmount = amt == null ? 0 : amt;
            Integer n = (Integer) ar.get('n');
            pulse.ytdOrderCount = n == null ? 0 : n;
        }

        for (Order ord : [
            SELECT Id, OrderNumber, Status, CreatedDate, TotalAmount
            FROM Order
            WHERE AccountId = :accountId
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 8
        ]) {
            OrderRow row = new OrderRow();
            row.id = ord.Id;
            row.orderNumber = ord.OrderNumber;
            row.status = ord.Status;
            row.effectiveDate = ord.CreatedDate == null ? null : ord.CreatedDate.date();
            row.totalAmount = ord.TotalAmount;
            pulse.recentOrders.add(row);
        }

        Set<String> closed = new Set<String>{
            'Accepted', 'Approved', 'Ordered', 'Denied', 'Rejected', 'Expired'
        };
        for (Quote q : [
            SELECT Id, Name, Status, GrandTotal, CreatedDate, RLM_Partner_Request__c
            FROM Quote
            WHERE AccountId = :accountId AND RLM_Partner_Request__c = true
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 8
        ]) {
            if (q.Status != null && closed.contains(q.Status)) {
                continue;
            }
            QuoteRow row = new QuoteRow();
            row.id = q.Id;
            row.name = q.Name;
            row.status = q.Status;
            row.grandTotal = q.GrandTotal;
            row.createdDate = q.CreatedDate == null ? null : q.CreatedDate.date();
            row.partnerRequest = q.RLM_Partner_Request__c == true;
            pulse.openQuotes.add(row);
        }
        pulse.openQuoteCount = pulse.openQuotes.size();
        return pulse;
    }

    @AuraEnabled(cacheable=true)
    public static QuoteSummary getQuoteSummary(String recordId) {
        QuoteSummary out = emptySummary();
        out.catalogs = listCatalogs();
        if (String.isBlank(recordId)) {
            return out;
        }
        Id quoteId;
        try {
            quoteId = Id.valueOf(recordId);
        } catch (Exception e) {
            AuraHandledException ex = new AuraHandledException('Invalid quote Id');
            ex.setMessage('Invalid quote Id');
            throw ex;
        }
        if (!String.valueOf(quoteId).startsWith('0Q0')) {
            return out;
        }
        List<Quote> quotes = [
            SELECT Id, Name, QuoteNumber, Status, GrandTotal, CreatedDate, Account.Name,
                   Account.OwnerId, RLM_Partner_Request__c, RLM_PC_Justification__c
            FROM Quote
            WHERE Id = :quoteId
            WITH USER_MODE
            LIMIT 1
        ];
        if (quotes.isEmpty()) {
            return out;
        }
        Quote q = quotes[0];
        out.id = q.Id;
        out.name = q.Name;
        out.quoteNumber = q.QuoteNumber;
        out.status = q.Status;
        out.accountName = q.Account != null ? q.Account.Name : null;
        out.createdDate = q.CreatedDate == null ? null : q.CreatedDate.date();
        out.grandTotal = q.GrandTotal;
        out.partnerRequest = q.RLM_Partner_Request__c == true;
        out.justification = q.RLM_PC_Justification__c;
        out.groups = groupQuoteLines(quoteId);
        out.solutionName = solutionNameFrom(out.groups);
        return out;
    }

    @AuraEnabled
    public static ConcessionResult requestPriceConcession(String recordId, String justification) {
        ConcessionResult out = new ConcessionResult();
        out.isSuccess = false;
        if (String.isBlank(justification) || justification.trim().length() < 8) {
            out.errorMessage = 'Add a short note for deal desk — what you need and why.';
            return out;
        }
        try {
            out = writeConcession(recordId, justification.trim());
        } catch (Exception e) {
            out.isSuccess = false;
            out.errorMessage = e.getMessage();
        }
        return out;
    }

    @AuraEnabled
    public static QtyResult updateParentQuantity(String recordId, String lineId, Decimal quantity) {
        QtyResult out = new QtyResult();
        out.isSuccess = false;
        out.updatedCount = 0;
        try {
            out = new QtyWriter().updateQuantity(recordId, lineId, quantity);
        } catch (Exception e) {
            out.isSuccess = false;
            out.errorMessage = e.getMessage();
        }
        return out;
    }

    @InvocableMethod(
        label='Submit Partner Price Concession'
        description='Stamps the partner price concession request and creates a Task for the account owner.'
    )
    public static List<ConcessionOutput> submitPartnerConcession(List<ConcessionInput> inputs) {
        List<ConcessionOutput> results = new List<ConcessionOutput>();
        if (inputs == null) {
            return results;
        }
        for (ConcessionInput input : inputs) {
            ConcessionOutput row = new ConcessionOutput();
            ConcessionResult submitted = requestPriceConcession(
                input == null ? null : input.quoteId,
                input == null ? null : input.justification
            );
            row.isSuccess = submitted.isSuccess;
            row.errorMessage = submitted.errorMessage;
            row.taskId = submitted.taskId;
            row.message = submitted.message;
            results.add(row);
        }
        return results;
    }

    private static QuoteSummary emptySummary() {
        QuoteSummary out = new QuoteSummary();
        out.groups = new List<QuoteGroup>();
        out.catalogs = new List<CatalogRow>();
        return out;
    }

    private static List<CatalogRow> listCatalogs() {
        List<CatalogRow> rows = new List<CatalogRow>();
        try {
            for (ProductCatalog catalog : [
                SELECT Id, Name
                FROM ProductCatalog
                WITH USER_MODE
                ORDER BY Name
                LIMIT 50
            ]) {
                CatalogRow row = new CatalogRow();
                row.id = catalog.Id;
                row.name = catalog.Name;
                row.subtitle = catalogCaption(catalog.Name);
                rows.add(row);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.FINE, 'Partner catalog query skipped: ' + e.getMessage());
        }
        if (rows.isEmpty()) {
            rows.add(catalogFallback('Catalog', 'Products available to order'));
        }
        return rows;
    }

    private static CatalogRow catalogFallback(String name, String caption) {
        CatalogRow row = new CatalogRow();
        row.name = name;
        row.subtitle = caption;
        return row;
    }

    private static String catalogCaption(String name) {
        return String.isBlank(name) ? 'Catalog' : 'Products available to order';
    }

    private static List<QuoteGroup> groupQuoteLines(Id quoteId) {
        List<QuoteLineRow> lines = new List<QuoteLineRow>();
        for (QuoteLineItem line : [
            SELECT Id, Quantity, ListPrice, TotalPrice, ParentQuoteLineItemId,
                   Product2.Name, Product2.StockKeepingUnit, Product2.ProductCode
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
            WITH USER_MODE
            ORDER BY LineNumber
        ]) {
            QuoteLineRow row = new QuoteLineRow();
            row.id = line.Id;
            row.productName = line.Product2 != null ? line.Product2.Name : 'Product';
            row.sku = lineSku(line);
            row.quantity = line.Quantity;
            row.listPrice = line.ListPrice;
            row.netAmount = line.TotalPrice;
            row.isParent = line.ParentQuoteLineItemId == null;
            row.groupName = lineGroupName(row.sku, row.productName, row.isParent);
            lines.add(row);
        }
        Map<String, QuoteGroup> byName = new Map<String, QuoteGroup>();
        List<QuoteGroup> groups = new List<QuoteGroup>();
        for (String name : new List<String>{
            'Kit', 'Device', 'Charging', 'Optional Accessories',
            'Software', 'Care', 'Services', 'Other'
        }) {
            QuoteGroup bucket = new QuoteGroup();
            bucket.name = name;
            bucket.lines = new List<QuoteLineRow>();
            bucket.netAmount = 0;
            byName.put(name, bucket);
        }
        for (QuoteLineRow row : lines) {
            QuoteGroup bucket = byName.get(row.groupName);
            if (bucket == null) {
                bucket = byName.get('Other');
            }
            bucket.lines.add(row);
            if (row.netAmount != null) {
                bucket.netAmount += row.netAmount;
            }
        }
        for (String name : new List<String>{
            'Kit', 'Device', 'Charging', 'Optional Accessories',
            'Software', 'Care', 'Services', 'Other'
        }) {
            QuoteGroup bucket = byName.get(name);
            if (bucket != null && !bucket.lines.isEmpty()) {
                groups.add(bucket);
            }
        }
        return groups;
    }

    private static String solutionNameFrom(List<QuoteGroup> groups) {
        if (groups == null) {
            return 'New solution';
        }
        for (QuoteGroup bucket : groups) {
            for (QuoteLineRow row : bucket.lines) {
                if (row.isParent && String.isNotBlank(row.productName)) {
                    return row.productName;
                }
            }
        }
        for (QuoteGroup bucket : groups) {
            if (!bucket.lines.isEmpty()) {
                return bucket.lines[0].productName;
            }
        }
        return 'New solution';
    }

    private static String lineSku(QuoteLineItem line) {
        if (line.Product2 == null) {
            return '';
        }
        if (String.isNotBlank(line.Product2.StockKeepingUnit)) {
            return line.Product2.StockKeepingUnit;
        }
        return line.Product2.ProductCode;
    }

    private static String lineGroupName(String sku, String productName, Boolean isParent) {
        if (isParent == true) {
            return 'Kit';
        }
        return 'Other';
    }

    private static ConcessionResult writeConcession(String recordId, String justification) {
        ConcessionResult out = new ConcessionResult();
        out.isSuccess = false;
        if (String.isBlank(recordId)) {
            out.errorMessage = 'Open a quote first.';
            return out;
        }
        Id quoteId;
        try {
            quoteId = Id.valueOf(recordId);
        } catch (Exception e) {
            out.errorMessage = 'Invalid quote Id';
            return out;
        }
        if (!String.valueOf(quoteId).startsWith('0Q0')) {
            out.errorMessage = 'Invalid quote Id';
            return out;
        }
        List<Quote> quotes = [
            SELECT Id, Name, AccountId, Account.Name, Account.OwnerId
            FROM Quote
            WHERE Id = :quoteId
            WITH USER_MODE
            LIMIT 1
        ];
        if (quotes.isEmpty()) {
            out.errorMessage = 'This quote is not available.';
            return out;
        }
        Quote quote = quotes[0];
        Quote patch = new Quote(
            Id = quote.Id,
            RLM_PC_Justification__c = justification,
            RLM_Partner_Request__c = true,
            RLM_Deal_Motion__c = 'Quote_To_Order'
        );
        new QuoteWriter().updateQuote(patch);
        String accountName = quote.Account != null ? quote.Account.Name : 'Partner';
        Id ownerId = quote.Account != null ? quote.Account.OwnerId : UserInfo.getUserId();
        Task job = new Task();
        job.Subject = 'Partner price concession — ' + accountName;
        job.Description = justification;
        job.WhatId = quote.Id;
        job.OwnerId = ownerId;
        job.Status = 'Not Started';
        job.Priority = 'High';
        job.ActivityDate = Date.today();
        try {
            new TaskWriter().insertTask(job);
            out.taskId = job.Id;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Partner concession Task skipped: ' + e.getMessage());
        }
        out.isSuccess = true;
        out.message = 'deal desk has your request. They will price the exception on this quote.';
        return out;
    }

    private without sharing class QuoteWriter {
        public void updateQuote(Quote patch) {
            update patch;
        }
    }

    private without sharing class TaskWriter {
        public void insertTask(Task job) {
            insert job;
        }
    }

    private without sharing class QtyWriter {
        public QtyResult updateQuantity(String recordId, String lineId, Decimal quantity) {
            QtyResult out = new QtyResult();
            out.isSuccess = false;
            out.updatedCount = 0;
            if (String.isBlank(recordId) || String.isBlank(lineId)) {
                out.errorMessage = 'Open a quote line first.';
                return out;
            }
            if (quantity == null || quantity < 1) {
                out.errorMessage = 'Enter a quantity of 1 or more.';
                return out;
            }
            Id quoteId;
            Id parentId;
            try {
                quoteId = Id.valueOf(recordId);
                parentId = Id.valueOf(lineId);
            } catch (Exception e) {
                out.errorMessage = 'Invalid quote or line Id';
                return out;
            }
            List<QuoteLineItem> parents = [
                SELECT Id, QuoteId, Quantity, ParentQuoteLineItemId
                FROM QuoteLineItem
                WHERE Id = :parentId AND QuoteId = :quoteId
                LIMIT 1
            ];
            if (parents.isEmpty()) {
                out.errorMessage = 'That line is not on this quote.';
                return out;
            }
            QuoteLineItem parent = parents[0];
            if (parent.ParentQuoteLineItemId != null) {
                out.errorMessage = 'Set quantity on the kit header. Child quantities follow the header.';
                return out;
            }
            Decimal oldQty = parent.Quantity == null || parent.Quantity == 0 ? 1 : parent.Quantity;
            Decimal newQty = quantity.setScale(0, RoundingMode.HALF_UP);
            List<QuoteLineItem> patches = new List<QuoteLineItem>{
                new QuoteLineItem(Id = parent.Id, Quantity = newQty)
            };
            for (QuoteLineItem child : [
                SELECT Id, Quantity
                FROM QuoteLineItem
                WHERE QuoteId = :quoteId AND ParentQuoteLineItemId = :parent.Id
            ]) {
                Decimal current = child.Quantity == null ? 0 : child.Quantity;
                Decimal scaled = (current * newQty / oldQty).setScale(0, RoundingMode.HALF_UP);
                if (scaled < 1) {
                    scaled = 1;
                }
                patches.add(new QuoteLineItem(Id = child.Id, Quantity = scaled));
            }
            update patches;
            out.isSuccess = true;
            out.updatedCount = patches.size();
            return out;
        }
    }

    private static AgreementRow toAgreementRow(SalesAgreement sa) {
        AgreementRow row = new AgreementRow();
        row.id = sa.Id;
        row.name = sa.Name;
        row.status = sa.Status;
        row.accountName = sa.Account != null ? sa.Account.Name : null;
        row.startDate = sa.StartDate;
        row.endDate = sa.EndDate;
        row.scheduleFrequency = sa.ScheduleFrequency;
        row.scheduleCount = sa.ScheduleCount;
        row.totalAmount = sa.TotalAgreementAmount;
        row.actualAmount = sa.TotalActualAgreementAmount;
        return row;
    }

    private static PriceRow toPriceRow(SalesAgreementProduct sap) {
        PriceRow row = new PriceRow();
        row.id = sap.Id;
        row.name = sap.Name;
        row.productName = sap.Product != null ? sap.Product.Name : sap.Name;
        row.sku = sap.Product != null && String.isNotBlank(sap.Product.StockKeepingUnit)
            ? sap.Product.StockKeepingUnit
            : sap.Name;
        row.agreementId = sap.SalesAgreementId;
        row.agreementName = sap.SalesAgreement != null ? sap.SalesAgreement.Name : null;
        row.listPrice = sap.ListPrice;
        row.discountPercentage = sap.DiscountPercentage;
        row.salesPrice = sap.SalesPrice;
        Decimal planned = sap.TotalPlannedQuantity;
        if (planned == null) {
            planned = sap.InitialPlannedQuantity;
        }
        row.plannedQuantity = planned;
        row.actualQuantity = sap.TotalActualQuantity;
        return row;
    }

    public class CallOffLine {
        @AuraEnabled public Id id;
        @AuraEnabled public Id productId;
        @AuraEnabled public String productName;
        @AuraEnabled public Decimal plannedQuantity;
        @AuraEnabled public Decimal salesPrice;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public Decimal childRatio;
        @AuraEnabled public Boolean isParent;
    }

    public class CallOffGroup {
        @AuraEnabled public String key;
        @AuraEnabled public String name;
        @AuraEnabled public Boolean isKit;
        @AuraEnabled public Decimal defaultQuantity;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public List<CallOffLine> lines;
    }

    public class CallOffSelection {
        @AuraEnabled public Id scheduleId { get; set; }
        @AuraEnabled public Decimal quantity { get; set; }
    }

    @AuraEnabled
    public static List<CallOffGroup> getCallOffLines(String salesAgreementId, Date orderDate) {
        Id saId = parseId(salesAgreementId, 'sales agreement Id');
        if (orderDate == null) {
            throw handled('Choose an order date.');
        }
        String sa15 = String.valueOf(saId).substring(0, 15);
        List<CallOffLine> rows = new List<CallOffLine>();
        Set<Id> productIds = new Set<Id>();
        for (SalesAgreementProductSchedule schedule : [
            SELECT
                Id,
                StartDate,
                EndDate,
                PlannedQuantity,
                SalesPrice,
                RLM_MFG_Product_Name__c,
                RLM_MFG_Product2Id__c
            FROM SalesAgreementProductSchedule
            WHERE RLM_MFG_SalesAgreementId__c = :sa15
                AND StartDate <= :orderDate
                AND EndDate > :orderDate
            WITH USER_MODE
            ORDER BY RLM_MFG_Product_Name__c, Name
            LIMIT 200
        ]) {
            CallOffLine row = new CallOffLine();
            row.id = schedule.Id;
            row.productId = toProductId(schedule.RLM_MFG_Product2Id__c);
            row.productName = schedule.RLM_MFG_Product_Name__c;
            if (String.isBlank(row.productName)) {
                row.productName = schedule.Id;
            }
            row.plannedQuantity = schedule.PlannedQuantity;
            row.salesPrice = schedule.SalesPrice;
            row.startDate = schedule.StartDate;
            row.endDate = schedule.EndDate;
            row.childRatio = 1;
            row.isParent = true;
            rows.add(row);
            if (row.productId != null) {
                productIds.add(row.productId);
            }
        }

        Map<Id, Id> parentByChild = new Map<Id, Id>();
        Map<Id, Decimal> ratioByChild = new Map<Id, Decimal>();
        loadBundleMaps(productIds, parentByChild, ratioByChild);
        applyKitNameFallback(rows, parentByChild, ratioByChild);
        return groupCallOffLines(rows, parentByChild, ratioByChild);
    }

    @AuraEnabled
    public static Id createCallOff(
        String salesAgreementId,
        Date orderDate,
        List<CallOffSelection> selections
    ) {
        Id saId = parseId(salesAgreementId, 'sales agreement Id');
        if (orderDate == null) {
            throw handled('Choose an order date.');
        }
        if (selections == null || selections.isEmpty()) {
            throw handled('Select at least one product.');
        }

        Map<Id, Integer> qtyBySchedule = new Map<Id, Integer>();
        for (CallOffSelection selection : selections) {
            if (selection == null || selection.scheduleId == null) {
                throw handled('Select at least one product.');
            }
            Integer qty = toCallOffQuantity(selection.quantity);
            if (qtyBySchedule.containsKey(selection.scheduleId)) {
                throw handled('Each product can only be selected once.');
            }
            qtyBySchedule.put(selection.scheduleId, qty);
        }

        List<SalesAgreement> agreements = [
            SELECT Id, AccountId, PricebookId, RLM_MFG_Contract__c
            FROM SalesAgreement
            WHERE Id = :saId
            WITH USER_MODE
            LIMIT 1
        ];
        if (agreements.isEmpty()) {
            throw handled('This agreement is not available to your account.');
        }

        String sa15 = String.valueOf(saId).substring(0, 15);
        Set<Id> requested = qtyBySchedule.keySet();
        List<SalesAgreementProductSchedule> schedules = [
            SELECT
                Id,
                PlannedQuantity,
                SalesPrice,
                RLM_MFG_Product2Id__c,
                RLM_MFG_PricebookEntryId__c
            FROM SalesAgreementProductSchedule
            WHERE Id IN :requested
                AND RLM_MFG_SalesAgreementId__c = :sa15
            WITH USER_MODE
        ];
        if (schedules.size() != requested.size()) {
            throw handled('One or more selected products are not on this agreement.');
        }

        for (SalesAgreementProductSchedule schedule : schedules) {
            schedule.PlannedQuantity = qtyBySchedule.get(schedule.Id);
        }

        SalesAgreement sa = agreements[0];
        RLM_MFG_SalesAgreementRLMOrder.saProductListEntries payload =
            new RLM_MFG_SalesAgreementRLMOrder.saProductListEntries();
        payload.salesagreementProductSchedules = schedules;
        payload.priceBookId = sa.PricebookId;
        payload.salesAgreementId = sa.Id;
        payload.customerAcctId = sa.AccountId;
        payload.orderDate = orderDate;
        payload.contractId = sa.RLM_MFG_Contract__c;

        try {
            List<String> created = RLM_MFG_SalesAgreementRLMOrder.createOrder(
                new List<RLM_MFG_SalesAgreementRLMOrder.saProductListEntries>{ payload }
            );
            if (created == null || created.isEmpty() || String.isBlank(created[0])) {
                throw handled('The order was not created.');
            }
            Id orderId = Id.valueOf(created[0]);
            System.enqueueJob(new RefreshActualsJob(sa.Id, UserInfo.getUserId()));
            return orderId;
        } catch (AuraHandledException e) {
            throw e;
        } catch (RLM_MFG_SalesAgreementRLMOrder.RLM_MFG_SalesAgreementOrderException e) {
            throw handled(e.getMessage());
        } catch (Exception e) {
            throw handled(e.getMessage());
        }
    }

    private static Integer toCallOffQuantity(Decimal quantity) {
        if (quantity == null || quantity <= 0) {
            throw handled('Enter a quantity of 1 or more.');
        }
        Integer qty = quantity.setScale(0, RoundingMode.HALF_UP).intValue();
        if (qty < 1) {
            throw handled('Enter a quantity of 1 or more.');
        }
        return qty;
    }

    private static Id toProductId(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        try {
            return Id.valueOf(raw);
        } catch (Exception e) {
            return null;
        }
    }

    private static void loadBundleMaps(
        Set<Id> productIds,
        Map<Id, Id> parentByChild,
        Map<Id, Decimal> ratioByChild
    ) {
        if (productIds == null || productIds.isEmpty()) {
            return;
        }
        try {
            for (ProductRelatedComponent prc : [
                SELECT ParentProductId, ChildProductId, Quantity
                FROM ProductRelatedComponent
                WHERE ParentProductId IN :productIds
                    AND ChildProductId IN :productIds
                WITH USER_MODE
                LIMIT 200
            ]) {
                if (prc.ParentProductId == null || prc.ChildProductId == null) {
                    continue;
                }
                parentByChild.put(prc.ChildProductId, prc.ParentProductId);
                Decimal ratio = prc.Quantity;
                ratioByChild.put(
                    prc.ChildProductId,
                    ratio == null || ratio <= 0 ? 1 : ratio
                );
            }
        } catch (System.QueryException e) {
            // Partner licenses may not query ProductRelatedComponent; kit-name fallback.
        }
    }

    @TestVisible
    private static void applyKitNameFallback(
        List<CallOffLine> lines,
        Map<Id, Id> parentByChild,
        Map<Id, Decimal> ratioByChild
    ) {
        if (parentByChild != null && !parentByChild.isEmpty()) {
            return;
        }
        CallOffLine parent;
        List<CallOffLine> children = new List<CallOffLine>();
        for (CallOffLine line : lines) {
            if (isKitParent(line)) {
                if (parent != null) {
                    return;
                }
                parent = line;
            } else {
                children.add(line);
            }
        }
        if (parent == null || parent.productId == null || children.isEmpty()) {
            return;
        }
        for (CallOffLine child : children) {
            if (child.productId == null) {
                continue;
            }
            parentByChild.put(child.productId, parent.productId);
            Decimal ratio = 1;
            if (
                parent.plannedQuantity != null
                && parent.plannedQuantity != 0
                && child.plannedQuantity != null
            ) {
                ratio = child.plannedQuantity / parent.plannedQuantity;
                if (ratio <= 0) {
                    ratio = 1;
                }
            }
            ratioByChild.put(child.productId, ratio);
        }
    }

    private static Boolean isKitParent(CallOffLine line) {
        String name = line.productName == null ? '' : line.productName.toLowerCase();
        if (name.contains('hardware kit')) {
            return true;
        }
        return (line.salesPrice == null || line.salesPrice == 0) && name.contains('kit');
    }

    @TestVisible
    private static List<CallOffGroup> groupCallOffLines(
        List<CallOffLine> lines,
        Map<Id, Id> parentByChild,
        Map<Id, Decimal> ratioByChild
    ) {
        List<CallOffGroup> groups = new List<CallOffGroup>();
        if (lines == null || lines.isEmpty()) {
            return groups;
        }
        if (parentByChild == null) {
            parentByChild = new Map<Id, Id>();
        }
        if (ratioByChild == null) {
            ratioByChild = new Map<Id, Decimal>();
        }

        Set<Id> parentIds = new Set<Id>(parentByChild.values());
        Set<Id> consumed = new Set<Id>();
        for (CallOffLine line : lines) {
            if (line.productId == null || !parentIds.contains(line.productId)) {
                continue;
            }
            if (consumed.contains(line.id)) {
                continue;
            }
            CallOffGroup kit = newCallOffGroup(line);
            line.isParent = true;
            line.childRatio = 1;
            kit.lines.add(line);
            consumed.add(line.id);
            for (CallOffLine candidate : lines) {
                if (candidate.productId == null || consumed.contains(candidate.id)) {
                    continue;
                }
                if (parentByChild.get(candidate.productId) != line.productId) {
                    continue;
                }
                candidate.isParent = false;
                Decimal ratio = ratioByChild.get(candidate.productId);
                candidate.childRatio = ratio == null || ratio <= 0 ? 1 : ratio;
                kit.lines.add(candidate);
                consumed.add(candidate.id);
            }
            kit.isKit = kit.lines.size() > 1;
            groups.add(kit);
        }
        for (CallOffLine line : lines) {
            if (consumed.contains(line.id)) {
                continue;
            }
            CallOffGroup kit = newCallOffGroup(line);
            kit.isKit = false;
            line.isParent = true;
            line.childRatio = 1;
            kit.lines.add(line);
            groups.add(kit);
        }
        return groups;
    }

    private static CallOffGroup newCallOffGroup(CallOffLine line) {
        CallOffGroup kit = new CallOffGroup();
        kit.key = String.valueOf(line.id);
        kit.name = line.productName;
        kit.isKit = false;
        kit.defaultQuantity = line.plannedQuantity;
        kit.startDate = line.startDate;
        kit.endDate = line.endDate;
        kit.lines = new List<CallOffLine>();
        return kit;
    }

    /**
     * Platform Sales Agreement actuals lag until refreshActualsCalculation runs.
     * Partner checkout (Quote.CreateOrder) does not enqueue that job, so pulse
     * would stay at $0 even when Activated orders already sit on the agreement.
     * Use posted order totals when they are ahead of TotalActualAgreementAmount.
     */
    @TestVisible
    private static void overlayOrderActuals(List<AgreementRow> rows) {
        if (rows == null || rows.isEmpty()) {
            return;
        }
        Set<Id> saIds = new Set<Id>();
        for (AgreementRow row : rows) {
            if (row != null && row.id != null) {
                saIds.add(row.id);
            }
        }
        if (saIds.isEmpty()) {
            return;
        }
        Map<Id, Decimal> postedByAgreement = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT SalesAgreementId saId, SUM(TotalAmount) amt
            FROM Order
            WHERE SalesAgreementId IN :saIds
                AND Status NOT IN ('Draft', 'Canceled')
            WITH USER_MODE
            GROUP BY SalesAgreementId
        ]) {
            Decimal amt = (Decimal) ar.get('amt');
            postedByAgreement.put((Id) ar.get('saId'), amt == null ? 0 : amt);
        }
        for (AgreementRow row : rows) {
            if (row == null || row.id == null) {
                continue;
            }
            Decimal posted = postedByAgreement.get(row.id);
            Decimal fromAgreement = row.actualAmount == null ? 0 : row.actualAmount;
            if (posted != null && posted > fromAgreement) {
                row.actualAmount = posted;
            }
        }
    }

    private static Id parseId(String value, String label) {
        if (String.isBlank(value)) {
            throw handled('Missing ' + label);
        }
        try {
            return Id.valueOf(value);
        } catch (Exception e) {
            throw handled('Invalid ' + label);
        }
    }

    private static AuraHandledException handled(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }

    public class RefreshActualsJob implements Queueable, Database.AllowsCallouts {
        private final Id salesAgreementId;
        private final Id notifyUserId;

        public RefreshActualsJob(Id salesAgreementId, Id notifyUserId) {
            this.salesAgreementId = salesAgreementId;
            this.notifyUserId = notifyUserId;
        }

        public void execute(QueueableContext context) {
            Map<String, Object> input = new Map<String, Object>{
                'userId' => notifyUserId,
                'salesAgreementId' => String.valueOf(salesAgreementId),
                'isCurrentSchedule' => false,
                'isCurrentAndFutureSchedules' => true
            };
            HttpRequest req = new HttpRequest();
            req.setEndpoint(
                URL.getOrgDomainUrl().toExternalForm()
                + '/services/data/v67.0/actions/standard/refreshActualsCalculation'
            );
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(new Map<String, Object>{
                'inputs' => new List<Object>{ input }
            }));
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
                throw new RefreshActualsException(
                    'Actuals refresh failed (' + res.getStatusCode() + '): ' + res.getBody()
                );
            }
        }
    }

    public class RefreshActualsException extends Exception {
    }
}
