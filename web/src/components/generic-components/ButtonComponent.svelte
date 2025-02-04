<script>
    import { createEventDispatcher } from "svelte";

    export let btnId = 'btn-0', btnLabel, isDisabled = false;

    const dispatch = createEventDispatcher();

    function submit() {
        if(!isDisabled) {
            dispatch("submit");
        }
    }
</script>

<button class="btn-wrapper {isDisabled ? 'cursor-not-allowed' : 'cursor-pointer'}" id={btnId} on:click={submit}>
    {btnLabel}
</button>

<style>
    .btn-wrapper {
        display: flex;
        flex-direction: row;

        background-color: var(--dd-bg);
        border-radius: 1vw;
        padding: 0.3vw 1.2vw;

        font-size: 0.8vw;
        font-weight: 400;
        color: var(--text);
    }

    .cursor-not-allowed {
        cursor: not-allowed;
    }

    .cursor-pointer {
        cursor: pointer;
    }
</style>