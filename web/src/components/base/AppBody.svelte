<script>
    import { onMount } from "svelte";
    import Spinner from "../generic-components/Spinner.svelte";
    import generalStore from "../../stores/generalStore";
    import fetchNui from "../../utils/fetch";
    import DropdownComponent from "../generic-components/DropdownComponent.svelte";
    import mainStore from "../../stores/mainStore";
    import { JSONEditor } from 'svelte-jsoneditor';

    const pageSizeOptions = [25, 50, 100, 250, 500];

    let isMounting = true;
    let isLoading = false;
    let errorMessage = null;
    let statusMessage = null;
    let dropdownValuesArray = [];
    let selectedDropdownValue = null;
    let originalJson = null;
    let content = null;
    let pageIds = [];
    let offset = 0;
    let pageSize = 50;
    let total = 0;
    let documentIdInput = '';
    let currentDocumentId = '';

    let { isDev } = generalStore;
    let { uiData } = mainStore;

    $: currentPage = total === 0 ? 0 : Math.floor(offset / pageSize) + 1;
    $: totalPages = total === 0 ? 0 : Math.ceil(total / pageSize);
    $: firstVisible = total === 0 ? 0 : offset + 1;
    $: lastVisible = currentDocumentId ? pageIds.length : Math.min(offset + pageSize, total);
    $: hasPrevious = !currentDocumentId && offset > 0;
    $: hasNext = !currentDocumentId && offset + pageSize < total;

    onMount(() => {
        retrieveDropdownValues();
        isMounting = false;
    });

    function retrieveDropdownValues() {
        dropdownValuesArray = [{ id: 'blank', name: 'Select collection' }].concat($uiData || []);
        selectDropdownValue(dropdownValuesArray[0]);
    }

    function selectDropdownValue(value) {
        errorMessage = null;
        statusMessage = null;
        selectedDropdownValue = value;
        originalJson = null;
        content = null;
        pageIds = [];
        offset = 0;
        total = 0;
        documentIdInput = '';
        currentDocumentId = '';
    }

    function setError(message) {
        errorMessage = message;
        statusMessage = null;
    }

    function setStatus(message) {
        statusMessage = message;
        errorMessage = null;
    }

    async function retrieveJsonDataForDisplay(nextOffset = 0, documentId = '') {
        if (!selectedDropdownValue || selectedDropdownValue.id === 'blank') {
            return;
        }

        isLoading = true;
        errorMessage = null;
        statusMessage = null;

        let response;
        if (!$isDev) {
            response = await fetchNui('getCollectionPage', {
                collection: selectedDropdownValue.name,
                offset: nextOffset,
                limit: pageSize,
                documentId,
            });
        } else {
            response = {
                ok: true,
                collection: selectedDropdownValue.name,
                documents: {},
                ids: [],
                offset: 0,
                limit: pageSize,
                total: 0,
            };
        }

        if (!response) {
            setError('No response from ChiliadDB.');
            isLoading = false;
            return;
        }

        if (response.ok === false || response.error) {
            setError(response.error || 'Failed to load collection data.');
            isLoading = false;
            return;
        }

        originalJson = response.documents || {};
        pageIds = response.ids || Object.keys(originalJson).map((id) => Number(id));
        offset = response.offset || 0;
        total = response.total || 0;
        currentDocumentId = documentId ? String(documentId) : '';
        content = {
            text: undefined,
            json: originalJson,
        };

        if (total === 0) {
            setStatus(`${selectedDropdownValue.name} has no documents.`);
        }

        isLoading = false;
    }

    function getContentSize(object) {
        return object && object.json ? Object.keys(object.json).length : 0;
    }

    async function loadSelectedCollection() {
        documentIdInput = '';
        currentDocumentId = '';
        await retrieveJsonDataForDisplay(0, '');
    }

    async function previousPage() {
        if (!hasPrevious) return;
        await retrieveJsonDataForDisplay(Math.max(offset - pageSize, 0), '');
    }

    async function nextPage() {
        if (!hasNext) return;
        await retrieveJsonDataForDisplay(offset + pageSize, '');
    }

    async function handlePageSizeChange(event) {
        pageSize = Number(event.target.value);
        documentIdInput = '';
        currentDocumentId = '';
        await retrieveJsonDataForDisplay(0, '');
    }

    async function jumpToDocument() {
        const documentId = String(documentIdInput || '').trim();
        if (!documentId) {
            currentDocumentId = '';
            await retrieveJsonDataForDisplay(0, '');
            return;
        }

        await retrieveJsonDataForDisplay(0, documentId);
    }

    async function clearDocumentJump() {
        documentIdInput = '';
        currentDocumentId = '';
        await retrieveJsonDataForDisplay(0, '');
    }

    async function refreshPage() {
        await retrieveJsonDataForDisplay(offset, currentDocumentId);
    }

    async function handleChange(updatedContent, previousContent, { patchResult }) {
        if (!selectedDropdownValue || selectedDropdownValue.id === 'blank' || !patchResult?.redo?.length) {
            return;
        }

        const collection = selectedDropdownValue.name;
        const action = patchResult.redo[0].op;
        const pathParts = patchResult.redo[0].path.split('/').filter(Boolean);
        const rootId = Number(pathParts[0]);

        if (getContentSize(updatedContent) > getContentSize(previousContent) && action === 'add' && pathParts.length === 1) {
            const newIndexData = await fetchNui('createNewIndex', { collection });
            if (!newIndexData) {
                setError('Failed to create a new document.');
                content = previousContent;
                return;
            }

            setStatus(`Created document ${newIndexData.id}.`);
            await refreshPage();
            return;
        }

        if (getContentSize(updatedContent) < getContentSize(previousContent) && action === 'remove' && pathParts.length === 1) {
            const response = await fetchNui('deleteDocument', { collection, id: rootId });
            if (!response) {
                setError(`Failed to delete document ${rootId}.`);
                content = previousContent;
                return;
            }

            setStatus(`Deleted document ${rootId}.`);
            await refreshPage();
            return;
        }

        if (!rootId) {
            setError('Could not determine which document changed.');
            content = previousContent;
            return;
        }

        const data = updatedContent.json[rootId];
        if (!data) {
            setError(`No data found for document ${rootId}.`);
            content = previousContent;
            return;
        }

        const response = await fetchNui('updateDocument', { collection, id: rootId, document: data });
        if (!response) {
            setError(`Failed to update document ${rootId}.`);
            content = previousContent;
            return;
        }

        content = updatedContent;
        setStatus(`Saved document ${rootId}.`);
    }
</script>

<div class="app-body explorer-body">
    {#if isMounting}
        <Spinner idValue='mounting-app-body' marginTop="15%" />
    {:else}
        <div class="explorer-toolbar">
            <div class="toolbar-section collection-section">
                <span class="field-label">Collection</span>
                <DropdownComponent
                    idValue='app-body-dd'
                    width='100%'
                    isDisabled={isLoading}
                    selectedValue={selectedDropdownValue}
                    dropdownItemsArray={dropdownValuesArray}
                    on:selected-value={(event) => {
                        selectDropdownValue(event.detail);
                        loadSelectedCollection();
                    }}
                />
            </div>

            <div class="toolbar-section compact-section">
                <label for="collection-page-size">Page size</label>
                <select id="collection-page-size" disabled={isLoading || !!currentDocumentId} bind:value={pageSize} on:change={handlePageSizeChange}>
                    {#each pageSizeOptions as option}
                        <option value={option}>{option}</option>
                    {/each}
                </select>
            </div>

            <div class="toolbar-section document-jump-section">
                <label for="document-id-jump">Document ID</label>
                <div class="inline-controls">
                    <input
                        id="document-id-jump"
                        type="number"
                        placeholder="Jump to ID"
                        disabled={isLoading || !selectedDropdownValue || selectedDropdownValue.id === 'blank'}
                        bind:value={documentIdInput}
                        on:keydown={(event) => event.key === 'Enter' && jumpToDocument()}
                    />
                    <button disabled={isLoading || !documentIdInput} on:click={jumpToDocument}>Go</button>
                    <button disabled={isLoading || !currentDocumentId} on:click={clearDocumentJump}>Clear</button>
                </div>
            </div>

            <button
                class="refresh-button"
                disabled={isLoading || !selectedDropdownValue || selectedDropdownValue.id === 'blank'}
                on:click={refreshPage}
            >
                Refresh
            </button>
        </div>

        <div class="pagination-bar">
            <div class="pagination-summary">
                {#if currentDocumentId}
                    Document {currentDocumentId} · Collection total: {total}
                {:else if total > 0}
                    Showing {firstVisible}-{lastVisible} of {total} · Page {currentPage} of {totalPages}
                {:else}
                    No documents loaded
                {/if}
            </div>

            <div class="pagination-controls">
                <button disabled={isLoading || !hasPrevious} on:click={previousPage}>Previous</button>
                <button disabled={isLoading || !hasNext} on:click={nextPage}>Next</button>
            </div>
        </div>

        {#if errorMessage || statusMessage}
            <div class="message-row {errorMessage ? 'error-message' : 'status-message'}">
                {errorMessage || statusMessage}
            </div>
        {/if}

        <div class="display-body-wrapper explorer-display">
            {#if isLoading}
                <Spinner idValue='loading-collection-page' marginTop="15%" />
            {:else if content}
                <div class="each-col jse-theme-dark">
                    <JSONEditor content={content} onChange={handleChange} />
                </div>
            {:else}
                <div class="empty-state">
                    <h3>Select a collection to inspect it</h3>
                    <p>Collections now load one page at a time to keep the explorer responsive on larger datasets.</p>
                </div>
            {/if}
        </div>
    {/if}
</div>
