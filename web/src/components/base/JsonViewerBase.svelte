<script>
    import RegularDropdownComponent from '../generic-components/RegularDropdownComponent.svelte';
    import ButtonComponent from '../generic-components/ButtonComponent.svelte';
    import Spinner from '../generic-components/Spinner.svelte';
    import mainStore from '../../stores/mainStore';
    import generalStore from '../../stores/generalStore';
    import fetchNui from '../../utils/fetch';
    import { JsonView } from '@zerodevx/svelte-json-view';

    let { uiData } = mainStore;
    let { isDev } = generalStore;
    const devData = {"global":{"ids":{"bans":1,"vehicles":1,"ox_doorlocks":1,"users":2,"logs":1,"characters":2}},"ox_inventory":{"character_inventory":{"1":[{"slot":1,"count":1,"name":"scrapmetal"},{"slot":3,"count":6,"name":"money"},{"slot":4,"count":1,"name":"burger"},{"slot":5,"count":2,"name":"mustard"}]}},"ox_core":{"ox_licenses":[{"name":"weapon","label":"Weapon License"},{"name":"driver","label":"Driver's License"}],"characters":{"1":{"x":1007.947265625,"lastPlayed":"2024-01-10","firstName":"Joe","isDead":false,"stateId":"OU58136","statuses":{"thirst":100,"hunger":68.52,"stress":0},"charId":1,"heading":266.4566955566406,"armour":0,"health":200,"lastName":"Szymkowicz","dateOfBirth":"1985-08-07","userId":1,"gender":"male","z":31.06591796875,"y":-1492.25927734375}},"users":{"b73e3e039dc918c533efd909722eb1da07231c2a":{"fivem":"1035100","license2":"b73e3e039dc918c533efd909722eb1da07231c2a","userId":1,"steam":"110000100c3a6cc","username":"nineX","discord":"225430972039036928"}},"user_chars":{"1":[1]},"ox_groups":[{"adminGrade":6,"hasAccount":false,"grades":["Cadet","Officer","Sergeant","Captain","Commander","Chief"],"label":"Los Santos Police Department","name":"police"},{"adminGrade":1,"hasAccount":false,"grades":["Dispatch"],"label":"Police Dispatch","name":"dispatch"}],"ox_statuses":[{"default":0,"name":"hunger","onTick":0.02},{"default":0,"name":"thirst","onTick":0.05},{"default":0,"name":"stress","onTick":-0.1}]},"js5m_admin":{"ids":{"bans":1,"logs":1}},"js5m_admin_OLD":{"ids":{"bans":1,"logs":1}}};

    let selectedDropdownValue = null;
    let errorMessage = '', json = null, isLoading = false;

    function handleDropdownSelection(selectedItem) {
        errorMessage = '';
        selectedDropdownValue = selectedItem;
    }

    async function handleSubmit() {
        isLoading = true;

        if(selectedDropdownValue && selectedDropdownValue.hasOwnProperty('id') && selectedDropdownValue?.id) {
            let response = {};
            if(!$isDev) {
                response = await fetchNui('', selectedDropdownValue);
            } else {
                response = devData[selectedDropdownValue.name];
                // response = {error: 'Error Message'};
            }

            if(response.hasOwnProperty('error')) {
                errorMessage = response.error;
            } else {
                json = response;
            }
        }

        isLoading = false;
    }
</script>

<div class="main-ui-base">
    <div class="heading-wrapper">
        <p class="heading">JSON VIEWER</p>
    </div>

    <div class="input-section-wrapper">
        <RegularDropdownComponent idValue="dropdown-main" dropdownOptions={$uiData} marginTop="0vw" on:selected-dropodwn-value={(event) => handleDropdownSelection(event.detail)} />

        <ButtonComponent btnId="submit-btn" btnLabel="Submit" isDisabled={!selectedDropdownValue} on:submit={handleSubmit} />
    </div>

    <div class="data-displayer">
        {#if isLoading}
            <Spinner idValue="submit-spinner" />
        {:else}
            {#if errorMessage.trim() !== ''}
                <p class="error-message">
                    {errorMessage}
                </p>
            {:else if json}
                <JsonView {json} />
            {/if}
        {/if}
    </div>
</div>