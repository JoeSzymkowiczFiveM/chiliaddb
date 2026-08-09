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

<div class="dropdown-wrap {isDropdownOpen ? 'dropdown-open' : ''}" style="width: {width};" bind:this={dropdownElement}>
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
        height: 2vw;
        z-index: 20;
    }

    .dropdown-open {
        z-index: 99999999;
    }

    .dropdown-wrapper {
        height: 100%;
        width: 100%;
        padding: 0 0.75vw;
        border: 1px solid rgba(255,255,255,0.25);
        border-radius: 0.3vw;
        background-color: var(--dd-bg);
        color: var(--text);
        display: flex;
        flex-direction: row;
        justify-content: space-between;
        gap: 1vw;
        align-items: center;
    }

    .selectedValue {
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
    }

    .drowndown-content-wrapper {
        position: absolute;
        left: 0;
        top: calc(100% + 0.25vw);
        z-index: 99999999;
        max-height: 11vw;
        width: 100%;
        border-radius: 0.3vw;
        border: 1px solid rgba(255,255,255,0.25);
        background-color: rgba(24, 24, 24, 0.98);
        box-shadow: 0 0.65vw 1.8vw rgba(0, 0, 0, 0.45);
        display: flex;
        flex-direction: column;
        overflow-y: auto;
        overscroll-behavior: contain;
        padding: 0.2vw 0;
    }

    .drowndown-content-wrapper::-webkit-scrollbar {
        width: 0.35vw !important;
    }

    .drowndown-content-wrapper::-webkit-scrollbar-thumb {
        background: var(--highlighted-text-light);
        border-radius: 1vw;
    }

    .each-dropdown-content-item {
        appearance: none;
        width: 100%;
        min-height: 1.75vw;
        display: flex;
        align-items: center;
        padding: 0.3vw 0.8vw;
        border: 0;
        border-radius: 0;
        border-left: 0.15vw solid transparent;
        background: transparent;
        color: var(--text);
        font-size: 0.78vw;
        text-align: left;
    }

    .each-dropdown-content-item + .each-dropdown-content-item {
        border-top: 1px solid rgba(255, 255, 255, 0.055);
    }

    .each-dropdown-content-item:hover:not(:disabled) {
        background-color: rgba(255, 255, 255, 0.06);
        color: white;
    }

    .selected-item {
        border-left-color: var(--highlighted-text);
        background-color: rgba(47, 109, 208, 0.16);
        color: rgb(255,255,255);
    }
</style>