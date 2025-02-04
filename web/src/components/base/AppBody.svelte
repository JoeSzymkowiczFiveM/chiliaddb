<script>
    import { onMount } from "svelte";
    import Spinner from "../generic-components/Spinner.svelte";
    import generalStore from "../../stores/generalStore";
    import fetchNui from "../../utils/fetch";
    import { responseData, responseDataAllDropdown } from "../../stores/devData";
    import DropdownComponent from "../generic-components/DropdownComponent.svelte";
    import mainStore from "../../stores/mainStore";
    import NumberInput from "../generic-components/NumberInput.svelte";
    import { JSONEditor } from 'svelte-jsoneditor';

    let isMounting = true;
    let isLoading = false, errorMessage = null;
    let dropdownValuesArray = [], selectedDropdownValue = null;
    let originalJson = null, json = null, fullContent = null, content = null, indexOfJsonArray;

    let { isDev } = generalStore;
    let { uiData } = mainStore;

    onMount(() => {
        isMounting = true;

        retrieveDropdownValues();

        isMounting = false;
    });

    function retrieveDropdownValues() {
        dropdownValuesArray = [{id: 'blank', name: 'Collection'}].concat($uiData);
        selectDropdownValue(dropdownValuesArray[0]);
    }

    function selectDropdownValue(value) {
        errorMessage = null;
        selectedDropdownValue = value;
    }

    function handleNumberInput(value) {
        errorMessage = null;
        indexOfJsonArray = value;

        let keys = Object.keys(originalJson);
        const objectSize = keys[keys.length - 1];

        if(indexOfJsonArray === null) {
            json = originalJson;
            content = {
                text: undefined,
                json: fullContent.json
            }
            return;
        }

        if (originalJson[indexOfJsonArray] === undefined) {
            errorMessage = `Index ${indexOfJsonArray} does not exist in this collection`;
            return;
        }

        if(objectSize && indexOfJsonArray <= objectSize) {
            const newJson = originalJson[indexOfJsonArray];
            // json = [newJson];

            // content = {
            //     text: undefined,
            //     json: newJson
            // }

            // create a json object and add an element to it with the key of indexOfJsonArray
            let json = {};
            json[indexOfJsonArray] = newJson;
            content = {
                text: undefined,
                json: json
            }
        }
    }

    async function retrieveJsonDataForDisplay() {
        if (selectedDropdownValue.id === 'blank') {
            return;
        }
        isLoading = true;

        let response = {};
        if(!$isDev) {
            response = await fetchNui('getCollectionData', selectedDropdownValue);
        } else {
            // response = selectedDropdownValue.id === "all" ? responseDataAllDropdown : responseData[selectedDropdownValue.name];
            // response = {error: 'Error Message'};
        }

        if (response.hasOwnProperty('0')) {
            response = response.reduce((acc, item, index) => {
            acc[index + 1] = item;
            return acc;
            }, {});
        }

        if(response.hasOwnProperty('error')) {
            errorMessage = response.error;
        } else {
            originalJson = response;
            json = response;
            content = {
                text: undefined,
                json
            }

            fullContent = {
                text: undefined,
                json
            }
        }

        isLoading = false;
    }

    // async function syncChanges() {
    //     console.log("syncing data: ", fullContent.json)
    //     if(!$isDev) {
    //         fetchNui('', {editedData: fullContent.json})
    //     }
    // }

    function handleChange(updatedContent, previousContent, { contentErrors, patchResult }) {
        content = updatedContent;
        let keys = Object.keys(originalJson);
        const objectSize = keys[keys.length - 1];

        if(indexOfJsonArray === null || (indexOfJsonArray && indexOfJsonArray > objectSize)) {
            fullContent = content
        } else {
            fullContent.json[indexOfJsonArray] = content.json
        }
        
        let id = parseInt(patchResult.redo[0].path.split('/')[1])
        let data = patchResult.json[id]
        let collection = selectedDropdownValue.name
        let action = patchResult.redo[0].op
        let submitData = {
            id: id, 
            collection: collection, 
            data: data, 
            action: action
        }
        
        fetchNui('onChangeData', submitData)
    }
</script>

<div class="app-body">
    {#if isMounting}
        <Spinner idValue='mounting-app-body' marginTop="15%" />
    {:else}
        <div class="input-wrapper">
            <div class="input-fields-wrapper">
                <DropdownComponent 
                    idValue='app-body-dd' isDisabled={isLoading}
                    selectedValue={selectedDropdownValue} dropdownItemsArray={dropdownValuesArray}
                    on:selected-value={(event) => {
                        selectDropdownValue(event.detail)
                        retrieveJsonDataForDisplay()
                    }}
                />

                <!-- <button class="get-data-btn" disabled={isLoading} on:click={retrieveJsonDataForDisplay}>
                    Get Data
                </button> -->
            </div>

            {#if json}
                <NumberInput 
                    idValue='index-of-json' inputValue={indexOfJsonArray} isDisabled={isLoading}
                    width="30%" placeholder="enter index of json array here"
                    on:number-input={(event) => handleNumberInput(event.detail)}
                />
            {/if}
        </div>

        <div class="display-body-wrapper">
            {#if errorMessage}
                <div class="error-message">{errorMessage}</div>
            {:else if originalJson}
                <div class="each-col jse-theme-dark">
                    <!-- <div class="each-col-heading">
                        <div class="heading">JSON EDITOR</div>
                        <button class="sync-btn" disabled={isLoading} on:click={syncChanges}>Sync changes</button>
                    </div> -->
                    <JSONEditor {content} onChange="{handleChange}" />
                </div>
            {/if}
        </div>
    {/if}
</div>