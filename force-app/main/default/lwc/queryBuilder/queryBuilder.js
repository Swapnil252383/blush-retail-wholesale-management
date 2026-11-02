import { LightningElement } from 'lwc';

import getObjects
    from '@salesforce/apex/QueryBuilderController.getObjects';

import getFields
    from '@salesforce/apex/QueryBuilderController.getFields';

import executeQuery
    from '@salesforce/apex/QueryBuilderController.executeQuery';

import saveQuery
    from '@salesforce/apex/QueryBuilderController.saveQuery';

import getSavedQueries
    from '@salesforce/apex/QueryBuilderController.getSavedQueries';

import getSavedQuery
    from '@salesforce/apex/QueryBuilderController.getSavedQuery';

export default class QueryBuilder extends LightningElement {

    objectOptions = [];
    fieldOptions = [];

    selectedObject = '';
    selectedFields = [];

    recordLimit = '500';
    soql = '';

    records = [];
    columns = [];

    errorMessage = '';
    successMessage = '';
    isLoading = false;

    // Save and load query properties
    queryName = '';
    savedQueryOptions = [];
    selectedSavedQuery = '';

    // Pagination properties
    pageSize = 10;
    currentPage = 1;

    limitOptions = [
        { label: '500', value: '500' },
        { label: '1000', value: '1000' },
        { label: '5000', value: '5000' },
        { label: '50000', value: '50000' }
    ];

    connectedCallback() {
        this.loadObjects();
        this.loadSavedQueries();
    }

    async loadObjects() {
        try {
            this.objectOptions = await getObjects();
        } catch (error) {
            this.showError(error);
        }
    }

    async loadSavedQueries() {
        try {
            this.savedQueryOptions = await getSavedQueries();
        } catch (error) {
            this.showError(error);
        }
    }

    // Select an object.
    async handleObjectChange(event) {
        this.selectedObject = event.detail.value;

        this.selectedFields = [];
        this.fieldOptions = [];
        this.records = [];
        this.columns = [];
        this.currentPage = 1;
        this.errorMessage = '';
        this.successMessage = '';

        try {
            this.fieldOptions = await getFields({
                objectName: this.selectedObject
            });

            this.generateQuery();
        } catch (error) {
            this.showError(error);
        }
    }

    handleFieldsChange(event) {
        this.selectedFields = [...event.detail.value];
        this.generateQuery();
    }

    handleLimitChange(event) {
        this.recordLimit = event.detail.value;
        this.generateQuery();
    }

    handleQueryChange(event) {
        this.soql = event.detail.value;
        this.errorMessage = '';
        this.successMessage = '';
    }

    handleQueryNameChange(event) {
        this.queryName = event.detail.value;
    }

    handleSavedQueryChange(event) {
        this.selectedSavedQuery = event.detail.value;
        this.errorMessage = '';
        this.successMessage = '';
    }

    // Generate SOQL from the selected object and fields.
    generateQuery() {
        if (!this.selectedObject) {
            this.soql = '';
            return;
        }

        const fields = [...new Set([
            'Id',
            ...this.selectedFields
        ])].sort();

        this.soql =
            `SELECT ${fields.join(', ')} ` +
            `FROM ${this.selectedObject} ` +
            `LIMIT ${this.recordLimit}`;
    }

    // Save the current editable SOQL.
    async handleSaveQuery() {
        this.errorMessage = '';
        this.successMessage = '';

        if (!this.queryName.trim()) {
            this.errorMessage = 'Please enter a query name.';
            return;
        }

        if (!this.soql.trim()) {
            this.errorMessage = 'Please enter a SOQL query to save.';
            return;
        }

        this.isLoading = true;

        try {
            const savedId = await saveQuery({
                queryName: this.queryName,
                soql: this.soql
            });

            await this.loadSavedQueries();

            this.selectedSavedQuery = savedId;

            this.successMessage =
                `Query "${this.queryName.trim()}" saved successfully.`;

        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    // Load the selected query from Salesforce.
    async handleLoadSavedQuery() {
        this.errorMessage = '';
        this.successMessage = '';

        if (!this.selectedSavedQuery) {
            this.errorMessage = 'Please select a saved query.';
            return;
        }

        this.isLoading = true;

        try {
            const savedSoql = await getSavedQuery({
                savedQueryId: this.selectedSavedQuery
            });

            this.soql = savedSoql || '';
            this.records = [];
            this.columns = [];
            this.currentPage = 1;
            this.selectedFields = [];

            // Synchronize the object dropdown when possible.
            const match = this.soql.match(
                /\bFROM\s+([a-zA-Z_][a-zA-Z0-9_.]*)/i
            );

            const objectName = match ? match[1] : '';

            const objectExists = this.objectOptions.some(
                option => option.value === objectName
            );

            if (objectExists) {
                this.selectedObject = objectName;

                this.fieldOptions = await getFields({
                    objectName: objectName
                });
            } else {
                this.selectedObject = '';
                this.fieldOptions = [];
            }

            const selectedOption = this.savedQueryOptions.find(
                option => option.value === this.selectedSavedQuery
            );

            this.successMessage = selectedOption
                ? `Loaded "${selectedOption.label}". Click Execute Query to run it.`
                : 'Saved query loaded. Click Execute Query to run it.';

        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    // Execute the current SOQL.
    async handleExecute() {
        this.isLoading = true;
        this.errorMessage = '';
        this.successMessage = '';
        this.records = [];
        this.columns = [];
        this.currentPage = 1;

        try {
            const result = await executeQuery({
                soql: this.soql,
                recordLimit: Number(this.recordLimit)
            });

            this.records = result.records || [];

            this.columns = [
                {
                    label: 'Record',
                    fieldName: 'RecordUrl',
                    type: 'url',
                    typeAttributes: {
                        label: { fieldName: 'RecordLabel' },
                        target: '_self'
                    }
                },

                ...this.selectedFields
                    .filter(field => field !== 'Id')
                    .map(field => ({
                        label: field,
                        fieldName: field,
                        type: 'text'
                    }))
            ];

            // Add any fields used in manually edited or saved SOQL.
            const displayedFields = new Set(
                this.columns.map(column => column.fieldName)
            );

            (result.fields || []).forEach(field => {
                if (
                    field !== 'Id' &&
                    field !== 'Name' &&
                    field !== 'RecordUrl' &&
                    field !== 'RecordLabel' &&
                    !displayedFields.has(field)
                ) {
                    this.columns.push({
                        label: field,
                        fieldName: field,
                        type: 'text'
                    });

                    displayedFields.add(field);
                }
            });

            if (this.records.length === 0) {
                this.successMessage = 'Query executed successfully. No records found.';
            }

        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    // Pagination: show 10 records per page.
    get paginatedRecords() {
        const startIndex = (this.currentPage - 1) * this.pageSize;
        const endIndex = startIndex + this.pageSize;

        return this.records.slice(startIndex, endIndex);
    }

    get totalPages() {
        return Math.ceil(this.records.length / this.pageSize);
    }

    get pageInfo() {
        return `Page ${this.currentPage} of ${this.totalPages}`;
    }

    get isPreviousDisabled() {
        return this.currentPage <= 1;
    }

    get isNextDisabled() {
        return this.currentPage >= this.totalPages;
    }

    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
        }
    }

    get hasResults() {
        return this.records.length > 0;
    }

    get resultCount() {
        return this.records.length;
    }

    showError(error) {
        this.errorMessage =
            error?.body?.message ||
            error?.message ||
            'Something went wrong.';

        this.successMessage = '';
    }
}