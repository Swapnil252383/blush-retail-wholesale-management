import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { open as openAgentforcePanel } from 'lightning/accApi';
import LightningConfirm from 'lightning/confirm';
import { createRecord } from 'lightning/uiRecordApi';
import TASK_OBJECT from '@salesforce/schema/Task';
import EVENT_OBJECT from '@salesforce/schema/Event';
import { refreshApex } from '@salesforce/apex';

import getRecordTypeOptions from '@salesforce/apex/BlushWorkspaceController.getRecordTypeOptions';
import getRecentProducts from '@salesforce/apex/BlushWorkspaceController.getRecentProducts';
import getRecentLeads from '@salesforce/apex/BlushWorkspaceController.getRecentLeads';
import getRecentAccounts from '@salesforce/apex/BlushWorkspaceController.getRecentAccounts';
import getRecentContacts from '@salesforce/apex/BlushWorkspaceController.getRecentContacts';
import getRecentTasks from '@salesforce/apex/BlushWorkspaceController.getRecentTasks';
import getRecentEvents from '@salesforce/apex/BlushWorkspaceController.getRecentEvents';
import getRecentCampaignMembers from '@salesforce/apex/BlushWorkspaceController.getRecentCampaignMembers';
import getRecentOpportunities from '@salesforce/apex/BlushWorkspaceController.getRecentOpportunities';
import getRecentOrders from '@salesforce/apex/BlushWorkspaceController.getRecentOrders';
import getRecentCampaigns from '@salesforce/apex/BlushWorkspaceController.getRecentCampaigns';
import getRecentStores from '@salesforce/apex/BlushWorkspaceController.getRecentStores';
import getProductPricing from '@salesforce/apex/BlushWorkspaceController.getProductPricing';
import getOrderSummary from '@salesforce/apex/BlushWorkspaceController.getOrderSummary';
import getOrderLineItems from '@salesforce/apex/BlushWorkspaceController.getOrderLineItems';
import getOpportunityLineItems from '@salesforce/apex/BlushWorkspaceController.getOpportunityLineItems';
import getAvailableProductsForOpportunity from '@salesforce/apex/BlushWorkspaceController.getAvailableProductsForOpportunity';
import addOpportunityProduct from '@salesforce/apex/BlushWorkspaceController.addOpportunityProduct';
import updateOrderItemLine from '@salesforce/apex/BlushWorkspaceController.updateOrderItemLine';
import deleteOrderItemLine from '@salesforce/apex/BlushWorkspaceController.deleteOrderItemLine';
import processOrderApproval from '@salesforce/apex/BlushWorkspaceController.processOrderApproval';
import getAvailableProducts from '@salesforce/apex/BlushWorkspaceController.getAvailableProducts';
import addOrderItem from '@salesforce/apex/BlushWorkspaceController.addOrderItem';
import updateOrderPayment from '@salesforce/apex/BlushWorkspaceController.updateOrderPayment';
import submitOrderForApproval from '@salesforce/apex/BlushWorkspaceController.submitOrderForApproval';
import runFollowUpBatch from '@salesforce/apex/BlushWorkspaceController.runFollowUpBatch';
import saveInvoicePdf from '@salesforce/apex/InvoiceController.saveInvoicePdf';

const productActions = [
    { label: 'View price book entries', name: 'pricing' },
    { label: 'Open product record', name: 'open' }
];
const standardOpenAction = [{ label: 'Open record', name: 'open' }];
const orderActions = [
    { label: 'Manage this order', name: 'work' },
    { label: 'Open order record', name: 'open' }
];
const opportunityActions = [
    { label: 'Add / view products', name: 'products' },
    { label: 'Open opportunity', name: 'open' }
];
const lineActions = [
    { label: 'Edit quantity / discount', name: 'edit' },
    { label: 'Remove line', name: 'delete' }
];

export default class BlushWorkspace extends NavigationMixin(LightningElement) {
    @api recordId;
    // Agent ID captured from the Agentforce Bot ID property in Lightning App Builder.
    // This remains configurable through the component's properties panel.
    @api agentforceBotId = '0Xxbm000004KTjVCAW';
    isOpeningAgentforce = false;
    activeTab = 'overview';
    opportunityChannel = 'Retail';
    orderChannel = 'Retail';
    accountChannel = 'Retail';
    defaultProductActive = true;
    selectedPricingProductId;
    selectedOrderId;
    selectedOpportunityId;
    selectedOpportunityEntryId;
    selectedActivityOpportunityId;
    selectedLineId;
    editLineQuantity = 1;
    editLineDiscount = 0;
    editLineDescription = '';
    selectedProductEntryId;
    quantity = 1;
    discountPerUnit = 0;
    lineDescription = '';
    paymentMode = 'UPI';
    paymentStatus = 'Paid';
    approvalComments = '';
    isAddingLine = false;
    isAddingOpportunityProduct = false;
    isSavingLineEdit = false;
    isProcessingApproval = false;
    isSavingPayment = false;
    isSubmittingApproval = false;
    isSavingInvoice = false;
    isRunningBatch = false;

    connectedCallback() {
        if (this.recordId) {
            this.selectedOrderId = this.recordId;
            this.activeTab = 'orders';
        }
    }

    @wire(getRecordTypeOptions, { objectApiName: 'Opportunity' }) opportunityTypes;
    @wire(getRecordTypeOptions, { objectApiName: 'Order' }) orderTypes;
    @wire(getRecordTypeOptions, { objectApiName: 'Account' }) accountTypes;
    @wire(getRecentProducts) productsWire;
    @wire(getRecentLeads) leadsWire;
    @wire(getRecentAccounts) accountsWire;
    @wire(getRecentContacts) contactsWire;
    @wire(getRecentTasks) tasksWire;
    @wire(getRecentEvents) eventsWire;
    @wire(getRecentCampaignMembers) campaignMembersWire;
    @wire(getRecentOpportunities) opportunitiesWire;
    @wire(getRecentOrders) ordersWire;
    @wire(getRecentCampaigns) campaignsWire;
    @wire(getRecentStores) storesWire;
    @wire(getProductPricing, { productId: '$selectedPricingProductId' }) pricingWire;
    @wire(getOrderSummary, { orderId: '$selectedOrderId' }) summaryWire;
    @wire(getOrderLineItems, { orderId: '$selectedOrderId' }) linesWire;
    @wire(getOpportunityLineItems, { opportunityId: '$selectedOpportunityId' }) opportunityLinesWire;
    @wire(getAvailableProductsForOpportunity, { opportunityId: '$selectedOpportunityId' }) opportunityProductChoicesWire;
    @wire(getAvailableProducts, { orderId: '$selectedOrderId' }) productChoicesWire;

    productColumns = [
        { label: 'Product', fieldName: 'Name', type: 'text' },
        { label: 'Code', fieldName: 'ProductCode', type: 'text' },
        { label: 'Category', fieldName: 'Category__c', type: 'text' },
        { label: 'Channels', fieldName: 'Sales_Channel__c', type: 'text', wrapText: true },
        { label: 'Retail / Base', fieldName: 'Base_Price__c', type: 'currency', typeAttributes: { currencyCode: 'INR' } },
        { label: 'Wholesale', fieldName: 'Wholesale_Price__c', type: 'currency', typeAttributes: { currencyCode: 'INR' } },
        { label: 'Active', fieldName: 'IsActive', type: 'boolean' },
        { type: 'action', typeAttributes: { rowActions: productActions } }
    ];
    leadColumns = [
        { label: 'Lead', fieldName: 'Name', type: 'text' },
        { label: 'Company', fieldName: 'Company', type: 'text' },
        { label: 'Email', fieldName: 'Email', type: 'email' },
        { label: 'Status', fieldName: 'Status', type: 'text' },
        { label: 'Channel', fieldName: 'Customer_Type__c', type: 'text' },
        { label: 'Converted', fieldName: 'IsConverted', type: 'boolean' },
        { type: 'action', typeAttributes: { rowActions: standardOpenAction } }
    ];
    opportunityColumns = [
        { label: 'Opportunity', fieldName: 'Name', type: 'text' },
        { label: 'Channel', fieldName: 'Sales_Channel__c', type: 'text' },
        { label: 'Stage', fieldName: 'StageName', type: 'text' },
        { label: 'Close Date', fieldName: 'CloseDate', type: 'date-local' },
        { label: 'Customer', fieldName: 'Customer_Name__c', type: 'text' },
        { type: 'action', typeAttributes: { rowActions: opportunityActions } }
    ];
    orderColumns = [
        { label: 'Order #', fieldName: 'OrderNumber', type: 'text' },
        { label: 'Channel', fieldName: 'Sales_Channel__c', type: 'text' },
        { label: 'Status', fieldName: 'Status', type: 'text' },
        { label: 'Payment', fieldName: 'Payment_Status__c', type: 'text' },
        { label: 'Approval', fieldName: 'Approval_Status__c', type: 'text' },
        { label: 'Payable', fieldName: 'Net_Amount__c', type: 'currency', typeAttributes: { currencyCode: 'INR' } },
        { type: 'action', typeAttributes: { rowActions: orderActions } }
    ];
    campaignColumns = [
        { label: 'Campaign', fieldName: 'Name', type: 'text' },
        { label: 'Type', fieldName: 'Type', type: 'text' },
        { label: 'Status', fieldName: 'Status', type: 'text' },
        { label: 'Start', fieldName: 'StartDate', type: 'date-local' },
        { label: 'End', fieldName: 'EndDate', type: 'date-local' },
        { label: 'Active', fieldName: 'IsActive', type: 'boolean' },
        { type: 'action', typeAttributes: { rowActions: standardOpenAction } }
    ];
    accountColumns = [
        { label: 'Account', fieldName: 'Name', type: 'text' },
        { label: 'Channel', fieldName: 'Sales_Channel__c', type: 'text' },
        { label: 'Phone', fieldName: 'Phone', type: 'phone' },
        { label: 'City', fieldName: 'BillingCity', type: 'text' },
        { label: 'State', fieldName: 'BillingState', type: 'text' },
        { type: 'action', typeAttributes: { rowActions: standardOpenAction } }
    ];
    contactColumns = [
        { label: 'Contact', fieldName: 'Name', type: 'text' },
        { label: 'Account', fieldName: 'AccountName', type: 'text' },
        { label: 'Email', fieldName: 'Email', type: 'email' },
        { label: 'Phone', fieldName: 'Phone', type: 'phone' },
        { type: 'action', typeAttributes: { rowActions: standardOpenAction } }
    ];
    taskColumns = [
        { label: 'Subject', fieldName: 'Subject', type: 'text' },
        { label: 'Due date', fieldName: 'ActivityDate', type: 'date-local' },
        { label: 'Status', fieldName: 'Status', type: 'text' },
        { label: 'Priority', fieldName: 'Priority', type: 'text' },
        { label: 'Reminder', fieldName: 'Is_Follow_Up_Reminder__c', type: 'boolean' },
        { type: 'action', typeAttributes: { rowActions: standardOpenAction } }
    ];
    eventColumns = [
        { label: 'Subject', fieldName: 'Subject', type: 'text' },
        { label: 'Start', fieldName: 'StartDateTime', type: 'date' },
        { label: 'End', fieldName: 'EndDateTime', type: 'date' },
        { label: 'Completed', fieldName: 'Is_Completed__c', type: 'boolean' },
        { type: 'action', typeAttributes: { rowActions: standardOpenAction } }
    ];
    campaignMemberColumns = [
        { label: 'Campaign', fieldName: 'CampaignName', type: 'text' },
        { label: 'Member', fieldName: 'MemberName', type: 'text' },
        { label: 'Member type', fieldName: 'MemberType', type: 'text' },
        { label: 'Status', fieldName: 'Status', type: 'text' },
        { type: 'action', typeAttributes: { rowActions: standardOpenAction } }
    ];
    opportunityLineColumns = [
        { label: 'Product', fieldName: 'ProductName', type: 'text' },
        { label: 'Code', fieldName: 'ProductCode', type: 'text' },
        { label: 'Quantity', fieldName: 'Quantity', type: 'number' },
        { label: 'Unit price', fieldName: 'UnitPrice', type: 'currency', typeAttributes: { currencyCode: 'INR' } },
        { label: 'Total', fieldName: 'TotalPrice', type: 'currency', typeAttributes: { currencyCode: 'INR' } }
    ];
    storeColumns = [
        { label: 'Store', fieldName: 'Name', type: 'text' },
        { label: 'City', fieldName: 'City__c', type: 'text' },
        { label: 'State', fieldName: 'State__c', type: 'text' },
        { label: 'GSTIN', fieldName: 'GSTIN__c', type: 'text' },
        { label: 'Default', fieldName: 'Is_Default__c', type: 'boolean' }
    ];
    lineColumns = [
        { label: 'Product', fieldName: 'Product_Name__c', type: 'text' },
        { label: 'Qty', fieldName: 'Quantity', type: 'number' },
        { label: 'Unit Price', fieldName: 'UnitPrice', type: 'currency', typeAttributes: { currencyCode: 'INR' } },
        { label: 'Discount / Unit', fieldName: 'Discount__c', type: 'currency', typeAttributes: { currencyCode: 'INR' } },
        { label: 'Discount %', fieldName: 'Discount_Percent__c', type: 'number', typeAttributes: { maximumFractionDigits: 2 } },
        { label: 'Taxable', fieldName: 'Taxable_Amount__c', type: 'currency', typeAttributes: { currencyCode: 'INR' } },
        { label: 'GST %', fieldName: 'GST_Rate__c', type: 'number' },
        { label: 'CGST', fieldName: 'CGST__c', type: 'currency', typeAttributes: { currencyCode: 'INR' } },
        { label: 'SGST', fieldName: 'SGST__c', type: 'currency', typeAttributes: { currencyCode: 'INR' } },
        { label: 'IGST', fieldName: 'IGST__c', type: 'currency', typeAttributes: { currencyCode: 'INR' } },
        { label: 'Net Line', fieldName: 'Net_Price__c', type: 'currency', typeAttributes: { currencyCode: 'INR' } },
        { type: 'action', typeAttributes: { rowActions: lineActions } }
    ];

    get products() { return this.productsWire?.data || []; }
    get leads() { return this.leadsWire?.data || []; }
    get accounts() { return this.accountsWire?.data || []; }
    get contacts() { return (this.contactsWire?.data || []).map((row) => ({ ...row, AccountName: row.Account?.Name || '' })); }
    get tasks() { return this.tasksWire?.data || []; }
    get events() { return this.eventsWire?.data || []; }
    get campaignMembers() { return (this.campaignMembersWire?.data || []).map((row) => ({ ...row, CampaignName: row.Campaign?.Name || '', MemberName: row.Lead?.Name || row.Contact?.Name || '', MemberType: row.LeadId ? 'Lead' : 'Contact' })); }
    get opportunities() { return this.opportunitiesWire?.data || []; }
    get orders() { return this.ordersWire?.data || []; }
    get campaigns() { return this.campaignsWire?.data || []; }
    get stores() { return this.storesWire?.data || []; }
    get pricingRows() { return this.pricingWire?.data || []; }
    get orderSummary() { return this.summaryWire?.data || {}; }
    get orderLines() { return this.linesWire?.data || []; }
    get availableProducts() { return this.productChoicesWire?.data || []; }
    get opportunityLines() { return (this.opportunityLinesWire?.data || []).map((row) => ({ ...row, ProductName: row.Product2?.Name || '', ProductCode: row.Product2?.ProductCode || '' })); }
    get opportunityProductChoices() { return this.opportunityProductChoicesWire?.data || []; }
    get hasOrderSummary() { return Boolean(this.summaryWire?.data); }
    get orderAccountName() { return this.summaryWire?.data?.Account?.Name || ''; }
    get isOrderNotSelected() { return !this.isOrderSelected; }
    get isApprovalActionDisabled() { return !this.isOrderSelected || !this.orderSummary || this.orderSummary.Approval_Status__c !== 'Pending' || this.isProcessingApproval; }
    get isApprovalSubmitDisabled() { return !this.canSubmitApproval || this.isSubmittingApproval; }
    get isLineEditVisible() { return Boolean(this.selectedLineId); }
    get isOpportunityNotSelected() { return !this.selectedOpportunityId; }
    get accountCount() { return this.accounts.length; }
    get contactCount() { return this.contacts.length; }
    get productCount() { return this.products.length; }
    get leadCount() { return this.leads.length; }
    get opportunityCount() { return this.opportunities.length; }
    get orderCount() { return this.orders.length; }
    get campaignCount() { return this.campaigns.length; }
    get hasPricingProduct() { return Boolean(this.selectedPricingProductId); }
    get isOrderSelected() { return Boolean(this.selectedOrderId); }
    get showWholesaleCompanyField() { return this.opportunityChannel === 'Wholesale'; }
    get channelOptions() { return [{ label: 'Retail / B2C', value: 'Retail' }, { label: 'Wholesale / B2B', value: 'Wholesale' }]; }
    get accountChannelOptions() { return this.channelOptions; }
    get paymentModeOptions() {
        return [
            { label: 'Cash', value: 'Cash' },
            { label: 'Card', value: 'Card' },
            { label: 'UPI', value: 'UPI' },
            { label: 'Net Banking', value: 'Net Banking' },
            { label: 'Cheque', value: 'Cheque' },
            { label: 'Razorpay', value: 'Razorpay' }
        ];
    }
    get paymentStatusOptions() { return [{ label: 'Pending', value: 'Pending' }, { label: 'Paid', value: 'Paid' }]; }
    get isRazorpayPayDisabled() {
        return !this.selectedOrderId ||
            this.isSavingPayment ||
            this.orderSummary?.Payment_Status__c === 'Paid';
    }
    get orderPickerOptions() {
        return this.orders.map((order) => ({ label: `${order.OrderNumber} · ${order.Status} · ${order.Account?.Name || 'Customer not loaded'}`, value: order.Id }));
    }
    get selectedOpportunityRecordTypeId() {
        const records = this.opportunityTypes?.data || [];
        return records.find((item) => item.developerName === this.opportunityChannel)?.value;
    }
    get accountTypeOptions() { return this.accountChannelOptions; }
    get selectedAccountRecordTypeId() {
        const records = this.accountTypes?.data || [];
        return records.find((item) => item.developerName === this.accountChannel)?.value;
    }
    get selectedOrderRecordTypeId() {
        const records = this.orderTypes?.data || [];
        return records.find((item) => item.developerName === this.orderChannel)?.value;
    }
    get canSubmitApproval() {
        return this.isOrderSelected && this.orderSummary && Number(this.orderSummary.Max_Discount_Percent__c || 0) > 10 &&
            !['Pending', 'Approved'].includes(this.orderSummary.Approval_Status__c);
    }
    get canGenerateInvoice() { return this.isOrderSelected && Boolean(this.orderSummary?.Invoice_Number__c); }
    get isAddLineDisabled() { return !this.isOrderSelected || this.isAddingLine; }
    get isInvoiceActionDisabled() { return !this.isOrderSelected || this.isSavingInvoice; }
    get isLineSaveDisabled() { return !this.selectedLineId || this.isSavingLineEdit; }
    get currentProductPrice() {
        const selected = this.availableProducts.find((item) => item.value === this.selectedProductEntryId);
        return selected ? selected.unitPrice : null;
    }
    get opportunityPickerOptions() { return this.opportunities.map((opp) => ({ label: opp.Name, value: opp.Id })); }
    get isRetailOrder() { return this.orderSummary?.Sales_Channel__c === 'Retail'; }
    get isOpportunityProductDisabled() { return !this.selectedOpportunityId || this.isAddingOpportunityProduct; }

    handleTabActive(event) { this.activeTab = event.target.value; }
    handleOpportunityChannelChange(event) { this.opportunityChannel = event.detail.value; }
    handleOrderChannelChange(event) { this.orderChannel = event.detail.value; }
    handleAccountChannelChange(event) { this.accountChannel = event.detail.value; }
    handleOpportunityPick(event) { this.selectedOpportunityId = event.detail.value; this.selectedOpportunityEntryId = undefined; }
    handleOpportunityProductPick(event) { this.selectedOpportunityEntryId = event.detail.value; }
    handleActivityOpportunityPick(event) { this.selectedActivityOpportunityId = event.detail.recordId; }
    handleProductPick(event) { this.selectedProductEntryId = event.detail.value; }
    handleQuantityChange(event) { this.quantity = Number(event.detail.value); }
    handleDiscountChange(event) { this.discountPerUnit = Number(event.detail.value || 0); }
    handleDescriptionChange(event) { this.lineDescription = event.detail.value; }
    handleEditLineQuantityChange(event) { this.editLineQuantity = Number(event.detail.value); }
    handleEditLineDiscountChange(event) { this.editLineDiscount = Number(event.detail.value || 0); }
    handleEditLineDescriptionChange(event) { this.editLineDescription = event.detail.value; }
    handleOrderPick(event) {
        this.selectedOrderId = event.detail.value;
        this.selectedProductEntryId = undefined;
        this.quantity = 1;
        this.discountPerUnit = 0;
    }
    handlePaymentModeChange(event) { this.paymentMode = event.detail.value; }
    handlePaymentStatusChange(event) { this.paymentStatus = event.detail.value; }
    handleApprovalCommentsChange(event) { this.approvalComments = event.detail.value; }

    async handleProductSuccess(event) {
        this.selectedPricingProductId = event.detail.id;
        this.notify('Product saved', 'Product was saved. The product trigger will synchronize eligible price book entries.', 'success');
        this.resetFields(event.target);
        await this.refreshLists();
    }
    async handleAccountSuccess(event) {
        this.notify('Account created', 'Account saved with the selected Retail / Wholesale record type.', 'success');
        this.resetFields(event.target);
        await this.refreshLists();
    }
    async handleContactSuccess(event) {
        this.notify('Contact created', 'Contact saved and linked to the selected Account.', 'success');
        this.resetFields(event.target);
        await this.refreshLists();
    }
    async handleLeadSuccess(event) {
        this.notify('Lead created', 'Lead saved successfully. Its email and phone can be used by the Opportunity customer-matching automation.', 'success');
        this.resetFields(event.target);
        await this.refreshLists();
    }
    async handleOpportunitySuccess(event) {
        this.notify('Opportunity created', 'Opportunity saved. Blush customer matching, channel checks and price book assignment have run.', 'success');
        this.selectedOpportunityId = event.detail.id;
        this.resetFields(event.target);
        await this.refreshLists();
        this.activeTab = 'sales';
    }
    async handleOrderSuccess(event) {
        this.selectedOrderId = event.detail.id;
        this.notify('Order created', 'Order saved. The Order trigger is applying defaults and copying Opportunity products where available.', 'success');
        this.resetFields(event.target);
        await this.refreshLists();
        this.activeTab = 'orders';
    }
    async handleCampaignSuccess(event) {
        this.notify('Campaign created', 'Campaign saved successfully.', 'success');
        this.resetFields(event.target);
        await this.refreshLists();
    }
    async handleCampaignMemberSuccess(event) {
        this.notify('Campaign member added', 'Lead or Contact was added to the Campaign.', 'success');
        this.resetFields(event.target);
        await this.refreshLists();
    }
    async handleOrderAddressSuccess(event) {
        this.notify('Billing address updated', 'Order address saved. Tax type and line taxes are recalculated by the Order automation when the state changes.', 'success');
        this.resetFields(event.target);
        await this.refreshLists();
    }
    async handleStoreSuccess(event) {
        this.notify('Store saved', 'Store record saved successfully.', 'success');
        this.resetFields(event.target);
        await this.refreshLists();
    }
    handleFormError(event) {
        const message = event.detail?.message || event.detail?.detail || 'Salesforce could not save this record. Check the highlighted fields and your access.';
        this.notify('Could not save record', message, 'error');
    }
    resetFields(form) {
        if (form) form.querySelectorAll('lightning-input-field').forEach((field) => field.reset());
    }

    async refreshLists() {
        const values = [this.productsWire, this.leadsWire, this.accountsWire, this.contactsWire, this.opportunitiesWire, this.ordersWire, this.campaignsWire, this.storesWire, this.tasksWire, this.eventsWire, this.campaignMembersWire];
        await Promise.all(values.filter(Boolean).map((value) => refreshApex(value)));
        if (this.selectedOrderId) await Promise.all([this.summaryWire, this.linesWire, this.productChoicesWire].filter(Boolean).map((value) => refreshApex(value)));
        if (this.selectedOpportunityId) await Promise.all([this.opportunityLinesWire, this.opportunityProductChoicesWire].filter(Boolean).map((value) => refreshApex(value)));
        if (this.selectedPricingProductId && this.pricingWire) await refreshApex(this.pricingWire);
    }

    async handleProductRowAction(event) {
        const { action, row } = event.detail;
        if (action.name === 'pricing') {
            this.selectedPricingProductId = row.Id;
            this.activeTab = 'catalog';
        } else if (action.name === 'open') {
            this.openRecord(row.Id);
        }
    }
    handleLeadRowAction(event) { this.openRecord(event.detail.row.Id); }
    handleOpportunityRowAction(event) {
        const { action, row } = event.detail;
        if (action.name === 'products') { this.selectedOpportunityId = row.Id; this.activeTab = 'sales'; }
        else this.openRecord(row.Id);
    }
    handleCampaignRowAction(event) { this.openRecord(event.detail.row.Id); }
    handleAccountRowAction(event) { this.openRecord(event.detail.row.Id); }
    handleContactRowAction(event) { this.openRecord(event.detail.row.Id); }
    handleTaskRowAction(event) { this.openRecord(event.detail.row.Id); }
    handleEventRowAction(event) { this.openRecord(event.detail.row.Id); }
    handleCampaignMemberRowAction(event) { this.openRecord(event.detail.row.Id); }
    handleOrderRowAction(event) {
        const { action, row } = event.detail;
        if (action.name === 'work') {
            this.selectedOrderId = row.Id;
            this.activeTab = 'orders';
        } else this.openRecord(row.Id);
    }

    async handleAddLine() {
        if (!this.selectedOrderId) {
            this.notify('Choose an order', 'Select an existing order or create a new one first.', 'warning');
            return;
        }
        if (!this.selectedProductEntryId) {
            this.notify('Choose a product', 'Select a product from this order’s price book.', 'warning');
            return;
        }
        if (!this.quantity || this.quantity <= 0) {
            this.notify('Invalid quantity', 'Quantity must be greater than zero.', 'error');
            return;
        }
        this.isAddingLine = true;
        try {
            await addOrderItem({
                orderId: this.selectedOrderId,
                pricebookEntryId: this.selectedProductEntryId,
                quantity: this.quantity,
                discountPerUnit: this.discountPerUnit || 0,
                description: this.lineDescription
            });
            this.notify('Order product added', 'Order product saved. GST, discounts, totals and approval checks have been recalculated by Apex.', 'success');
            this.selectedProductEntryId = undefined;
            this.quantity = 1;
            this.discountPerUnit = 0;
            this.lineDescription = '';
            await this.refreshLists();
        } catch (error) {
            this.notify('Could not add order product', this.errorMessage(error), 'error');
        } finally {
            this.isAddingLine = false;
        }
    }

    async handleAddOpportunityProduct() {
        if (!this.selectedOpportunityId || !this.selectedOpportunityEntryId) {
            this.notify('Choose Opportunity and product', 'Select an Opportunity and an eligible product from its channel price book.', 'warning');
            return;
        }
        const quantityField = this.template.querySelector('[data-id="opportunityQuantity"]');
        const descriptionField = this.template.querySelector('[data-id="opportunityProductDescription"]');
        const quantityValue = Number(quantityField?.value || 1);
        if (quantityValue <= 0) {
            this.notify('Invalid quantity', 'Opportunity product quantity must be greater than zero.', 'error');
            return;
        }
        this.isAddingOpportunityProduct = true;
        try {
            await addOpportunityProduct({
                opportunityId: this.selectedOpportunityId,
                pricebookEntryId: this.selectedOpportunityEntryId,
                quantity: quantityValue,
                description: descriptionField?.value || ''
            });
            this.notify('Opportunity product added', 'The product line was saved with the channel price. Orders created from this Opportunity can copy these products.', 'success');
            this.selectedOpportunityEntryId = undefined;
            if (quantityField) quantityField.value = 1;
            if (descriptionField) descriptionField.value = '';
            await Promise.all([this.opportunitiesWire, this.opportunityLinesWire, this.opportunityProductChoicesWire].filter(Boolean).map((value) => refreshApex(value)));
        } catch (error) {
            this.notify('Could not add Opportunity product', this.errorMessage(error), 'error');
        } finally {
            this.isAddingOpportunityProduct = false;
        }
    }

    async handleLineRowAction(event) {
        const { action, row } = event.detail;
        if (action.name === 'delete') {
            const confirmed = await LightningConfirm.open({
                label: 'Remove order product?',
                message: `Remove ${row.Product_Name__c || row.Product2?.Name || 'this product'} from the Order? Taxes and totals will be recalculated.`,
                theme: 'warning'
            });
            if (!confirmed) return;
            try {
                await deleteOrderItemLine({ orderItemId: row.Id });
                this.notify('Order product removed', 'The line was removed and the parent Order totals were recalculated.', 'success');
                if (this.selectedLineId === row.Id) this.selectedLineId = undefined;
                await this.refreshLists();
            } catch (error) {
                this.notify('Could not remove order product', this.errorMessage(error), 'error');
            }
            return;
        }
        this.selectedLineId = row.Id;
        this.editLineQuantity = Number(row.Quantity || 1);
        this.editLineDiscount = Number(row.Discount__c || 0);
        this.editLineDescription = row.Description || '';
    }
    handleCancelLineEdit() { this.selectedLineId = undefined; }
    async handleSaveLineEdit() {
        if (!this.selectedLineId) return;
        this.isSavingLineEdit = true;
        try {
            await updateOrderItemLine({
                orderItemId: this.selectedLineId,
                quantity: this.editLineQuantity,
                discountPerUnit: this.editLineDiscount,
                description: this.editLineDescription
            });
            this.notify('Order product updated', 'Discount, line taxes, order totals and the approval threshold were recalculated.', 'success');
            this.selectedLineId = undefined;
            await this.refreshLists();
        } catch (error) {
            this.notify('Could not update order product', this.errorMessage(error), 'error');
        } finally {
            this.isSavingLineEdit = false;
        }
    }

    async handleApprovalAction(event) {
        const actionName = event.currentTarget.dataset.action;
        if (!this.selectedOrderId) return;
        this.isProcessingApproval = true;
        try {
            const message = await processOrderApproval({ orderId: this.selectedOrderId, actionName, comments: this.approvalComments });
            this.notify(`Discount ${actionName.toLowerCase()} result`, message, 'success');
            this.approvalComments = '';
            await this.refreshLists();
        } catch (error) {
            this.notify(`Discount ${actionName.toLowerCase()} failed`, this.errorMessage(error), 'error');
        } finally {
            this.isProcessingApproval = false;
        }
    }

    handleTaskSubmit(event) {
        event.preventDefault();
        if (!this.selectedActivityOpportunityId) { this.notify('Select an Opportunity', 'Choose the related Opportunity before saving a follow-up Task.', 'warning'); return; }
        const fields = { ...event.detail.fields };
        fields.WhatId = this.selectedActivityOpportunityId;
        createRecord({ apiName: TASK_OBJECT.objectApiName, fields })
            .then(() => {
                this.notify('Task created', 'Task saved and linked to the selected Opportunity.', 'success');
                this.resetFields(event.target);
                this.selectedActivityOpportunityId = undefined;
                return Promise.all([this.tasksWire, this.opportunitiesWire].filter(Boolean).map((value) => refreshApex(value)));
            })
            .catch((error) => this.notify('Task could not be created', this.errorMessage(error), 'error'));
    }
    handleEventSubmit(event) {
        event.preventDefault();
        if (!this.selectedActivityOpportunityId) { this.notify('Select an Opportunity', 'Choose the related Opportunity before saving an Event.', 'warning'); return; }
        const fields = { ...event.detail.fields };
        fields.WhatId = this.selectedActivityOpportunityId;
        createRecord({ apiName: EVENT_OBJECT.objectApiName, fields })
            .then(() => {
                this.notify('Event created', 'Event saved and linked to the selected Opportunity.', 'success');
                this.resetFields(event.target);
                this.selectedActivityOpportunityId = undefined;
                return Promise.all([this.eventsWire, this.opportunitiesWire].filter(Boolean).map((value) => refreshApex(value)));
            })
            .catch((error) => this.notify('Event could not be created', this.errorMessage(error), 'error'));
    }

    async handleSavePayment() {
        if (!this.selectedOrderId) {
            this.notify('Choose an order', 'Select an order before updating payment details.', 'warning');
            return;
        }
        this.isSavingPayment = true;
        try {
            const message = await updateOrderPayment({ orderId: this.selectedOrderId, paymentMode: this.paymentMode, paymentStatus: this.paymentStatus });
            this.notify('Payment updated', message, 'success');
            await this.refreshLists();
        } catch (error) {
            this.notify('Payment update blocked', this.errorMessage(error), 'error');
        } finally {
            this.isSavingPayment = false;
        }
    }

    handlePayWithRazorpay() {
        if (!this.selectedOrderId) {
            this.notify(
                'Choose an order',
                'Select a Blush Order before starting Razorpay Checkout.',
                'warning'
            );
            return;
        }

        if (this.orderSummary?.Payment_Status__c === 'Paid') {
            this.notify(
                'Order already paid',
                'This Order is already marked Paid. A new payment cannot be started from this screen.',
                'warning'
            );
            return;
        }

        // Open synchronously from the button click so the browser
        // is less likely to block the new tab. The Visualforce page
        // creates the Razorpay Order and verifies the final payment.
        const checkoutUrl =
            '/apex/RazorpayCheckoutPage?orderId=' +
            encodeURIComponent(this.selectedOrderId);

        const checkoutWindow = window.open(checkoutUrl, '_blank');

        if (!checkoutWindow) {
            this.notify(
                'Popup blocked',
                'Allow popups for Salesforce, then click Pay with Razorpay again.',
                'warning'
            );
            return;
        }

        this.notify(
            'Razorpay Checkout opened',
            'Complete the test payment in the new tab. Refresh this workspace after payment verification to see the updated Order status.',
            'info'
        );
    }

    async handleSubmitApproval() {
        if (!this.selectedOrderId) return;
        this.isSubmittingApproval = true;
        try {
            const message = await submitOrderForApproval({ orderId: this.selectedOrderId, comments: this.approvalComments });
            this.notify('Discount approval', message, 'success');
            this.approvalComments = '';
            await this.refreshLists();
        } catch (error) {
            this.notify('Approval submission failed', this.errorMessage(error), 'error');
        } finally {
            this.isSubmittingApproval = false;
        }
    }

    handlePreviewInvoice() {
        if (!this.selectedOrderId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: `/apex/BlushInvoice?id=${this.selectedOrderId}` }
        });
    }
    async handleSaveInvoice() {
        if (!this.selectedOrderId) return;
        this.isSavingInvoice = true;
        try {
            const contentDocumentId = await saveInvoicePdf({ orderId: this.selectedOrderId });
            this.notify('Invoice saved', 'PDF invoice has been saved to the Order Files.', 'success');
            this[NavigationMixin.Navigate]({
                type: 'standard__namedPage',
                attributes: { pageName: 'filePreview' },
                state: { selectedRecordId: contentDocumentId }
            });
        } catch (error) {
            this.notify('Invoice could not be saved', this.errorMessage(error), 'error');
        } finally {
            this.isSavingInvoice = false;
        }
    }

    async handleRunBatch() {
        this.isRunningBatch = true;
        try {
            const jobId = await runFollowUpBatch();
            this.notify('Follow-up batch started', `Batch job ${jobId} was queued. Refresh Tasks after the job completes.`, 'success');
        } catch (error) {
            this.notify('Batch could not be started', this.errorMessage(error), 'error');
        } finally {
            this.isRunningBatch = false;
        }
    }

    async handleOpenAgentforce() {
        if (this.isOpeningAgentforce) return;
        this.isOpeningAgentforce = true;
        try {
            const configuredBotId = (this.agentforceBotId || '').trim();
            if (configuredBotId) {
                await openAgentforcePanel(configuredBotId);
            } else {
                await openAgentforcePanel();
            }
        } catch (error) {
            this.notify(
                'Could not open Blush Project Guide',
                this.errorMessage(error),
                'error'
            );
        } finally {
            this.isOpeningAgentforce = false;
        }
    }

    navigateToReports() { this.navigateUrl('/lightning/o/Report/home'); }
    navigateToDashboards() { this.navigateUrl('/lightning/o/Dashboard/home'); }
    navigateToApprovalRequests() { this.navigateUrl('/lightning/o/ProcessInstanceWorkitem/home'); }
    navigateToCampaigns() { this.navigateUrl('/lightning/o/Campaign/home'); }
    navigateToTasks() { this.navigateUrl('/lightning/o/Task/home'); }
    navigateUrl(url) {
        this[NavigationMixin.Navigate]({ type: 'standard__webPage', attributes: { url } });
    }
    openRecord(recordId) {
        if (!recordId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, actionName: 'view' }
        });
    }
    notify(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode: variant === 'error' ? 'sticky' : 'dismissible' }));
    }
    errorMessage(error) {
        return error?.body?.message || error?.message || 'Unexpected error. Check Salesforce debug logs and your object/field permissions.';
    }
}