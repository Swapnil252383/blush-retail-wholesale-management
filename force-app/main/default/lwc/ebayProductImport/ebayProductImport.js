import { LightningElement } from 'lwc';

import searchListings from
    '@salesforce/apex/EBayProductController.searchListings';

import addListingToProducts from
    '@salesforce/apex/EBayProductController.addListingToProducts';

import { ShowToastEvent } from
    'lightning/platformShowToastEvent';


export default class EbayProductImport extends LightningElement {

    searchTerm = '';
    listings = [];

    isSearching = false;
    hasSearched = false;
    errorMessage = '';

    // Change this to the marketplace configured for your use case.
    marketplaceId = 'EBAY_US';


    // Product categories supported by Blush.
    categoryOptions = [
        {
            label: 'Garments',
            value: 'Garments'
        },
        {
            label: 'Jewellery',
            value: 'Jewellery'
        }
    ];


    // Available selling channels.
    channelOptions = [
        {
            label: 'Retail',
            value: 'Retail'
        },
        {
            label: 'Wholesale',
            value: 'Wholesale'
        }
    ];


    // --------------------------------------------------
    // GETTERS
    // --------------------------------------------------

    get hasResults() {
        return this.listings.length > 0;
    }


    get showNoResults() {
        return (
            this.hasSearched &&
            !this.isSearching &&
            !this.errorMessage &&
            this.listings.length === 0
        );
    }


    // --------------------------------------------------
    // SEARCH INPUT
    // --------------------------------------------------

    handleSearchTermChange(event) {
        this.searchTerm = event.detail.value;
    }


    handleKeyUp(event) {
        if (event.key === 'Enter') {
            this.handleSearch();
        }
    }


    // --------------------------------------------------
    // SEARCH EBAY
    // --------------------------------------------------

    async handleSearch() {

        if (!this.searchTerm || !this.searchTerm.trim()) {

            this.showToast(
                'Search required',
                'Enter a product name first.',
                'warning'
            );

            return;
        }

        this.isSearching = true;
        this.hasSearched = false;
        this.errorMessage = '';
        this.listings = [];

        try {

            const response = await searchListings({
                searchTerm: this.searchTerm.trim(),
                marketplaceId: this.marketplaceId
            });

            this.listings = (response || []).map((row) => {

                let displayPrice = 'Price unavailable';

                if (
                    row.supplierPrice !== null &&
                    row.supplierPrice !== undefined
                ) {
                    displayPrice =
                        `${row.currencyCode || ''} ${row.supplierPrice}`.trim();
                }

                return {
                    ...row,

                    displayPrice,

                    // Blush product details
                    category: '',
                    basePrice: '',
                    salesChannels: ['Retail'],

                    // Import state
                    isSaving: false,
                    isImported: false,
                    importedMessage: '',
                    importButtonLabel: 'Add to Salesforce Products',

                    // Image state
                    showImage: Boolean(row.imageUrl)
                };
            });

            this.hasSearched = true;

            if (this.listings.length === 0) {

                this.showToast(
                    'No listings found',
                    'Try another product name.',
                    'info'
                );
            }

        } catch (error) {

            this.errorMessage = this.getErrorMessage(error);
            this.hasSearched = true;

            this.showToast(
                'Search failed',
                this.errorMessage,
                'error'
            );

        } finally {

            this.isSearching = false;
        }
    }


    // --------------------------------------------------
    // HANDLE IMAGE LOADING ERRORS
    // --------------------------------------------------

    handleImageError(event) {

        const itemId = event.currentTarget.dataset.id;

        if (!itemId) {
            return;
        }

        // Hide the broken image and render the fallback.
        this.updateListing(itemId, {
            showImage: false
        });
    }


    // --------------------------------------------------
    // HANDLE FORM FIELD CHANGES
    // --------------------------------------------------

    handleFieldChange(event) {

        const itemId = event.target.dataset.id;
        const fieldName = event.target.dataset.field;

        if (!itemId || !fieldName) {
            return;
        }

        const value =
            event.detail &&
            event.detail.value !== undefined
                ? event.detail.value
                : event.target.value;

        this.updateListing(itemId, {
            [fieldName]: value
        });
    }


    // --------------------------------------------------
    // IMPORT SELECTED LISTING INTO PRODUCT2
    // --------------------------------------------------

    async handleAddProduct(event) {

        const itemId = event.currentTarget.dataset.id;

        const item = this.listings.find(
            (row) => row.itemId === itemId
        );

        if (!item) {

            this.showToast(
                'Product not found',
                'Search for the listing again.',
                'error'
            );

            return;
        }

        // Prevent repeated imports from this result card.
        if (item.isSaving || item.isImported) {
            return;
        }


        // Validate category.
        if (!item.category) {

            this.showToast(
                'Category required',
                'Select Garments or Jewellery.',
                'warning'
            );

            return;
        }


        // Validate Blush selling price.
        const retailPrice = Number(item.basePrice);

        if (
            item.basePrice === '' ||
            item.basePrice === null ||
            item.basePrice === undefined ||
            !Number.isFinite(retailPrice) ||
            retailPrice <= 0
        ) {

            this.showToast(
                'Price required',
                'Enter a valid Blush retail selling price.',
                'warning'
            );

            return;
        }


        // Validate sales channels.
        if (
            !item.salesChannels ||
            item.salesChannels.length === 0
        ) {

            this.showToast(
                'Sales channel required',
                'Select Retail, Wholesale, or both.',
                'warning'
            );

            return;
        }


        // Start import.
        this.updateListing(itemId, {
            isSaving: true,
            importedMessage: ''
        });

        try {

            const result = await addListingToProducts({

                itemId: item.itemId,

                category: item.category,

                basePrice: retailPrice,

                salesChannels: item.salesChannels,

                marketplaceId: this.marketplaceId
            });


            // Update the result card after Apex succeeds.
            this.updateListing(itemId, {

                isSaving: false,

                isImported: true,

                importButtonLabel: result.alreadyExists
                    ? 'Already in Blush Catalogue'
                    : 'Product Imported',

                importedMessage:
                    `${result.message} Product ID: ${result.productId}`
            });


            this.showToast(

                result.alreadyExists
                    ? 'Product already exists'
                    : 'Product imported successfully',

                result.message,

                result.alreadyExists
                    ? 'info'
                    : 'success'
            );

        } catch (error) {

            this.updateListing(itemId, {
                isSaving: false
            });

            this.showToast(
                'Import failed',
                this.getErrorMessage(error),
                'error'
            );
        }
    }


    // --------------------------------------------------
    // UPDATE ONE LISTING WITHOUT RESETTING OTHER CARDS
    // --------------------------------------------------

    updateListing(itemId, changes) {

        this.listings = this.listings.map((row) => {

            if (row.itemId === itemId) {

                return {
                    ...row,
                    ...changes
                };
            }

            return row;
        });
    }


    // --------------------------------------------------
    // ERROR MESSAGE HELPER
    // --------------------------------------------------

    getErrorMessage(error) {

        if (error?.body?.message) {
            return error.body.message;
        }

        if (error?.message) {
            return error.message;
        }

        return 'An unexpected error occurred. Please try again.';
    }


    // --------------------------------------------------
    // TOAST MESSAGE HELPER
    // --------------------------------------------------

    showToast(title, message, variant) {

        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

}