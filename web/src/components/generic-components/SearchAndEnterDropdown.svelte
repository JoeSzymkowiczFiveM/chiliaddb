<script>
    import { faArrowTurnDown } from "@fortawesome/free-solid-svg-icons";
    import fetchNui from "../../utils/fetch";
    import generalStore from "../../stores/generalStore";
    import { onMount, createEventDispatcher } from "svelte";
    import Fa from "svelte-fa";

    export let idValue = 'search-and-enter-dropdown-id', width = '10vw', marginTop = '-1vw', marginBottom = '', marginLeft = '', marginRight = '';
    export let placeholder = "Search and hit enter.. ", inputDisabled = false;
    
    let { isDev } = generalStore;
    
    let dropdownOptions = [], isDropdownOpen = false, selectedDropdownOption = dropdownOptions[0], textInputValue = '';
    const dispatch = createEventDispatcher();

    onMount(() => {
        const dropdownBaseWrapper = document.getElementById('dropdown-content-id'+idValue);
        dropdownBaseWrapper.style.width = width;

        const inputField = document.getElementById('input-box-search-and-enter-dd'+idValue);
        inputField.style.width = width;

        if(marginBottom.trim() !== '') {
            dropdownBaseWrapper.style.marginBottom = marginBottom;
        }

        if(marginTop.trim() !== '') {
            dropdownBaseWrapper.style.marginTop = marginTop;
        }

        if(marginRight.trim() !== '') {
            dropdownBaseWrapper.style.marginRight = marginRight;
        }

        if(marginLeft.trim() !== '') {
            dropdownBaseWrapper.style.marginLeft = marginLeft;
        }
    });
    
    function toggleDropdown() {
        if(!inputDisabled) {
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
        selectedDropdownOption = option;
        textInputValue = selectedDropdownOption.name;

        toggleDropdown();
        dispatch('selected-dropodwn-value', selectedDropdownOption.id);
        inputDisabled = true;
    }

    async function handleEnterKeyClick(event) {
        if(event.key === 'Enter' && textInputValue.trim() !== '' && !inputDisabled) {
            let response = [];

            if($isDev) {
                response = [{id: 1, name: 'Sakshi'}, {id: 2, name: 'Shruti'}, {id: 3, name: 'Ashwini'}, {id: 4, name: 'Pushkar'}];
                // response = [];
                // response = [{id: 1, name: 'Sakshi'}];
            } else {
                response = await fetchNui('getPlayers', {searchString: textInputValue});
            }
            
            dropdownOptions = response.length > 0 ? response : 'No results found for the search.';
            isDropdownOpen = response.length > 0;

            if(isDropdownOpen) {
                const dropdownContentComponent = document.getElementById('dropdown-content-id'+idValue);
                dropdownContentComponent.style.height = 'auto';
                dropdownContentComponent.style.maxHeight = '7.5vw';
            }
        }
    }
</script>

<div id={idValue} class="dropdown-base-wrapper" style="width=auto;">
    <div id={"dropdown-content-id"+idValue} class="dropdown-content">
        <input type="text" disabled={inputDisabled} id={"input-box-search-and-enter-dd"+idValue} style="width=100%;" class="input-wrapper" placeholder={placeholder} bind:value={textInputValue} on:keypress={(event) => handleEnterKeyClick(event)} />
        <div class="enter-icon">
            <Fa icon={faArrowTurnDown} />
        </div>
        
        {#if isDropdownOpen && typeof dropdownOptions === 'object'}
            <div id={"dropdown-options-id"+idValue} class="dropdown-options-body">
                {#each dropdownOptions as option}
                    <div class="each-option each-option-height {option === selectedDropdownOption ? 'selected-option' : ''}" on:click={() => selectDropdownOption(option)}>
                        {option.name}
                    </div>
                {/each}
            </div>
        {/if} 
    </div>
    {#if dropdownOptions.length > 0 && !isDropdownOpen && typeof dropdownOptions !== 'object'}
        <p class="no-results-found">{dropdownOptions}</p>
    {/if} 
</div>

<style>
    .enter-icon {
        position: absolute;
        transform: rotate(-270deg);
        margin-top: -1vw;
        margin-left: 9vw;
        color: var(--inactive-text-color-69);
    }

    .dropdown-base-wrapper {
        position: relative;
        /* z-index: 99999; */
        display: inline-block;
    }

    .dropdown-base-wrapper > .no-results-found {
        margin-top: 0.5vw;

        font-size: 0.7vw;
        font-weight: 300;
        
        position: absolute;
        
        width: 12vw;
    }

    .dropdown-base-wrapper > .dropdown-content {
        border-radius: 0.2vw;

        background-color: var(--input-box-bg);
        /* box-shadow: 0.2vw 0.2vw 0.2vw var(--input-shadow); */

        font-size: 0.7vw;
        min-height: 1.5vw;

        position: absolute;
    }

    .dropdown-base-wrapper > .dropdown-content > .input-wrapper {
        border-radius: 0.2vw;

        background-color: var(--input-box-bg);

        padding: 0.1vw 0.3vw;
        font-size: 0.7vw;
        height: 1.5vw;
    }
    .dropdown-base-wrapper > .dropdown-content > .input-wrapper:focus {
        outline: none;
    }
    .dropdown-base-wrapper > .dropdown-content > .input-wrapper::placeholder {
        font-size: 0.7vw;
        font-weight: 200;
        color: var(--inactive-text-color-50);
    }

    .dropdown-base-wrapper > .dropdown-content > .dropdown-options-body {
        padding: 0.2vw 0.2vw;
        height: auto;
        max-height: 5.5vw;
        overflow-y: auto;
    }

    .dropdown-base-wrapper > .dropdown-content > .dropdown-options-body > .each-option {
        height: 1.3vw;
        background-color: var(--dropdown-row);
        
        border-radius: 0.15vw;
        padding: 0.14vw 0.22vw;
        margin-top: 0.2vw;

        font-size: 0.65vw;
        font-weight: 250;
        color: var(--inactive-text-color-78);
        
        cursor: pointer;
    }

    .dropdown-base-wrapper > .dropdown-content > .dropdown-options-body > .each-option-height:not(:first-child) {
        margin-top: 0.2vw;
    }

    .dropdown-base-wrapper > .dropdown-content > .dropdown-options-body > .selected-option {
        background-color: var(--green) !important;
        /* text-shadow: 0 4px 4px var(--text-shadow); */
        /* box-shadow: 0.2vw 0.2vw 0.4vw var(--shadow); */
    }
</style>