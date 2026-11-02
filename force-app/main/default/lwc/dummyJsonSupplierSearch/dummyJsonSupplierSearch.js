import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchProducts from '@salesforce/apex/DummyJsonSupplierController.searchProducts';
import importSelectedProducts from '@salesforce/apex/DummyJsonSupplierController.importSelectedProducts';

const COLUMNS = [
    { label: 'Sample ID', fieldName: 'id', type: 'text', initialWidth: 100 },
    { label: 'Product', fieldName: 'title', type: 'text', wrapText: true },
    { label: 'Category', fieldName: 'category', type: 'text', initialWidth: 170 },
    { label: 'Demo price (not INR)', fieldName: 'price', type: 'number',
      typeAttributes: { minimumFractionDigits: 2, maximumFractionDigits: 2 }, initialWidth: 170 },
    { label: 'Sample stock (not Blush stock)', fieldName: 'stock', type: 'number', initialWidth: 190 }
];

export default class DummyJsonSupplierSearch extends LightningElement {
    searchTerm = '';
    selectedCategory = 'all';
    products = [];
    selectedIds = [];
    isLoading = false;
    hasSearched = false;
    errorMessage;
    columns = COLUMNS;

    categoryOptions = [
        { label: 'All products', value: 'all' },
        { label: 'Jewellery sample', value: 'womens-jewellery' },
        { label: 'Garments sample — dresses', value: 'womens-dresses' },
        { label: 'Garments sample — tops', value: 'tops' },
        { label: 'Garments sample — shirts', value: 'mens-shirts' }
    ];

    connectedCallback() {
        this.loadProducts();
    }

    get hasResults() {
        return this.products.length > 0;
    }

    get showNoResults() {
        return this.hasSearched && !this.isLoading && !this.errorMessage && this.products.length === 0;
    }

    get disableImport() {
        return this.isLoading || this.selectedIds.length === 0;
    }

    handleSearchTermChange(event) {
        this.searchTerm = event.target.value;
    }

    handleCategoryChange(event) {
        this.selectedCategory = event.detail.value;
    }

    handleKeyDown(event) {
        if (event.key === 'Enter') {
            this.handleSearch();
        }
    }

    handleSearch() {
        this.loadProducts();
    }

    async loadProducts() {
        this.isLoading = true;
        this.errorMessage = undefined;
        this.selectedIds = [];
        try {
            const rows = await searchProducts({
                searchTerm: this.searchTerm,
                category: this.selectedCategory
            });
            this.products = rows || [];
            this.hasSearched = true;
        } catch (error) {
            this.products = [];
            this.hasSearched = true;
            this.errorMessage = this.getErrorMessage(error);
            this.showToast('Search failed', this.errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleRowSelection(event) {
        this.selectedIds = event.detail.selectedRows.map((row) => String(row.id));
    }

    async handleImport() {
        this.isLoading = true;
        try {
            const count = await importSelectedProducts({ externalIds: this.selectedIds });
            this.showToast('Import complete', `${count} listing record(s) saved or refreshed in Salesforce.`, 'success');
            this.selectedIds = [];
        } catch (error) {
            this.showToast('Import failed', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    getErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        return 'An unexpected error occurred. Check the Salesforce debug log and Named Credential.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}