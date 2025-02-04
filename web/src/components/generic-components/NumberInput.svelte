<script>
    import { createEventDispatcher, onMount } from "svelte";

    export let inputValue, idValue, placeholder = '', isDisabled = false, allowDecimal = true;
    export let width = '100%', height = '2vw';

    const dispatch = createEventDispatcher();

    onMount(() => {
        const inputField = document.getElementById(`number-input-${idValue}`);
        if(inputField) {
            inputField.style.width = width;
            inputField.style.height = height;
        }
    })

    function handleInput() {
        if(!allowDecimal) {
            inputValue = parseInt(inputValue);
        }
        dispatch('number-input', inputValue);
    }
</script>

<input 
    id="number-input-{idValue}" type="number" disabled={isDisabled} 
    class="number-input" placeholder="{placeholder}" 
    bind:value={inputValue} on:keyup={handleInput} 
/>

<style>
    .number-input {
        background-color: var(--black-0096);
        border: 1px solid var(--white-009);
        padding: 0 0.5vw;
    }

    .number-input::placeholder {
        font-size: 0.65vw;
        font-weight: 100;
        color: var(--white-04);
        text-transform: capitalize;
    }
</style>