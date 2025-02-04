<script>
    import { faChevronDown, faChevronUp } from "@fortawesome/free-solid-svg-icons";
    import { onMount, createEventDispatcher } from "svelte";
    import Fa from "svelte-fa";

    export let idValue = 'regular-dropdown-id', width = '10vw', marginTop = '-1vw', marginBottom = '', marginLeft = '', marginRight = '';
    export let dropdownOptions = [{id: 'all', name: 'All'}, {id: 'deposit', name: 'Deposit'}, {id: 'withdraw', name: 'Withdraw'}, {id: 'transfer', name: 'Transfer'}]
    export let selectedRowHeight = '1.5vw';
    export let selectedDdValue = null, isDisabled = false;

    let isDropdownOpen = false;
    const dispatch = createEventDispatcher();

    onMount(() => {
        const dropdownContentWrapper = document.getElementById('dropdown-content-id'+idValue);
        dropdownContentWrapper.style.width = width;

        const dropdownBaseWrapper = document.getElementById(idValue);
        if(marginBottom.trim() !== '') {
            dropdownBaseWrapper.style.marginBottom = marginBottom;
        }

        if(marginTop.trim() !== '') {
            dropdownBaseWrapper.style.marginTop = marginTop;
        }

        if(marginLeft.trim() !== '') {
            dropdownBaseWrapper.style.marginLeft = marginLeft;
        }

        if(marginRight.trim() !== '') {
            dropdownBaseWrapper.style.marginRight = marginRight;
        }

        const selectedRowComponent = document.getElementById("selected-row-id"+idValue);
        selectedRowComponent.style.height = selectedRowHeight;
    });
    
    function toggleDropdown() {
        if(!isDisabled) {
            const dropdownContentComponent = document.getElementById('dropdown-content-id'+idValue);

            if(!isDropdownOpen) {
                dropdownContentComponent.style.height = 'auto';
                dropdownContentComponent.style.maxHeight = '7.5vw';
            } else {
                dropdownContentComponent.style.height = 'auto';
            }

            isDropdownOpen = !isDropdownOpen;
        }
    }

    function selectDropdownOption(option) {
        if(!isDisabled) {
            selectedDdValue = option;
            toggleDropdown();
            dispatch('selected-dropodwn-value', selectedDdValue);
        }
    }
</script>

<div id={idValue} class="dropdown-base-wrapper" style="width=auto;">
    <div id={"dropdown-content-id"+idValue} class="dropdown-content {isDisabled ? 'cursor-not-allowed' : 'cursor-pointer'}">
        <div id={"selected-row-id"+idValue} class="selected-row" on:click={toggleDropdown}>
            <p class="selected-value-text">
                {selectedDdValue ? selectedDdValue.name : ''}
            </p>
            <div class="dropdown-chevron-icon">
                <Fa icon={!isDropdownOpen ? faChevronDown : faChevronUp} />
            </div>
        </div>
        
        {#if isDropdownOpen}
            <div id={"dropdown-options-id"+idValue} class="dropdown-options-body">
                {#each dropdownOptions as option}
                    <div class="each-option each-option-height {option === selectedDdValue ? 'selected-option' : ''}" on:click={() => selectDropdownOption(option)}>
                        {option.name}
                    </div>
                {/each}
            </div>
        {/if}
    </div>
</div>

<style>
    .dropdown-base-wrapper {
        position: relative;
        z-index: 99999;
        /* display: inline-block; */
    }

    .dropdown-base-wrapper > .dropdown-content {
        border-radius: 0.2vw;

        background-color: var(--dd-bg);
        box-shadow: 1px 1px 2px var(--drop-shadow);

        padding: 0.13vw 0.3vw;
        font-size: 0.7vw;
        min-height: 1.5vw;

        cursor: pointer;
        position: absolute;
    }

    .dropdown-base-wrapper > .dropdown-content > .selected-row {
        display: flex;
        flex-direction: row;
        justify-content: space-between;

        padding: 0.14vw 0.3vw;
        /* height: 1.5vw; */
    }

    .dropdown-base-wrapper > .dropdown-content > .selected-row > .selected-value-text {
       padding-left: 0.1vw;
       color: var(--text);
    }

    .dropdown-base-wrapper > .dropdown-content > .selected-row > .dropdown-chevron-icon {
        padding-top: 0.15vw;
        color: var(--text);
    }

    .dropdown-base-wrapper > .dropdown-content > .dropdown-options-body {
        padding: 0.2vw 0.2vw;
        height: auto;
        max-height: 5.5vw;
        overflow-y: auto;
    }

    .dropdown-base-wrapper > .dropdown-content > .dropdown-options-body > .each-option {
        height: 1.3vw;
        
        border-radius: 0.15vw;
        padding: 0.2vw 0.22vw;
        margin-top: 0.2vw;

        font-size: 0.65vw;
        font-weight: 250;
        color: var(--text);
    }

    .dropdown-base-wrapper > .dropdown-content > .dropdown-options-body > .each-option:hover {
        background-color: var(--highlighted-text) !important;
        color: var(--dd-bg);
        font-weight: 400;
    }

    .dropdown-base-wrapper > .dropdown-content > .dropdown-options-body > .each-option-height:not(:first-child) {
        margin-top: 0.2vw;
    }

    .dropdown-base-wrapper > .dropdown-content > .dropdown-options-body > .selected-option {
        background-color: var(--highlighted-text) !important;
        color: var(--dd-bg);
        font-weight: 500;
        /* text-shadow: 0 4px 4px var(--text-shadow); */
        /* box-shadow: 0.2vw 0.2vw 0.4vw var(--shadow); */
    }
</style>