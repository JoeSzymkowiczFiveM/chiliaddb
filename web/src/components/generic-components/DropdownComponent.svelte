<script>
    import { faChevronDown, faChevronUp } from "@fortawesome/free-solid-svg-icons";
    import { createEventDispatcher, onMount, onDestroy } from "svelte";
    import Fa from "svelte-fa";

    export let idValue, width='70%', isDisabled;
    export let dropdownItemsArray, selectedValue;

    let isDropdownOpen = false;
    const dispatch = createEventDispatcher();
    let dropdownElement;

    function toggleDropdown() {
        isDropdownOpen = !isDropdownOpen;
    }

    function selectValue(value) {
        selectedValue = value;
        dispatch('selected-value', value);
        toggleDropdown();
    }

    function handleClickOutside(event) {
        if (dropdownElement && !dropdownElement.contains(event.target)) {
            isDropdownOpen = false;
        }
    }

    onMount(() => {
        document.addEventListener('click', handleClickOutside);
    });

    onDestroy(() => {
        document.removeEventListener('click', handleClickOutside);
    });
</script>

<div class="dropdown-wrap" style="width: {width};" bind:this={dropdownElement}>
    <button id='dropdown-{idValue}' class="dropdown-wrapper" disabled={isDisabled} on:click={toggleDropdown}>
        <div class="selectedValue">{selectedValue.name}</div>
        <Fa icon={isDropdownOpen ? faChevronUp : faChevronDown} />
    </button>
    
    {#if isDropdownOpen}
        <div class="drowndown-content-wrapper">
            {#each dropdownItemsArray as dropdownItem}
                <button 
                    class="each-dropdown-content-item {selectedValue.id === dropdownItem.id ? 'selected-item' : ''}"
                    disabled={isDisabled}
                    on:click={() => selectValue(dropdownItem)}
                >
                    {dropdownItem.name}
                </button>
            {/each}
        </div>
    {/if}
</div>

<style>
    .dropdown-wrap {
        position: relative;
        height: 100%;
        z-index: 99999999;
    }

    .dropdown-wrapper {
        height: 90%;
        width: inherit;
        padding: 0 0.75vw;
        border: 1px solid rgba(255,255,255,0.55);
        border-radius: 0.2vw;
        display: flex;
        flex-direction: row;
        justify-content: space-between;
        gap: 1vw;
        align-items: center;
    }

    .drowndown-content-wrapper {
        z-index: 99999999;
        margin-top: 0.25vw;
        height: 9vw;
        width: inherit;
        border-radius: 0.2vw;
        border: 1px solid rgba(255,255,255,0.55);
        background-color: var(--bg);
        display: flex;
        flex-direction: column;
        gap: 0.5vw;
        overflow-y: auto;
    }

    .each-dropdown-content-item {
        height: 1.5vw;
        display: flex;
        align-items: center;
        padding: 0.25vw 0.5vw;
        font-size: 0.8vw;
    }

    .selected-item {
        border-radius: 0.2vw;
        background-color: var(--highlighted-text-025);
        color: rgb(255,255,255);
    }
</style>