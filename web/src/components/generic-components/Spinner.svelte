<script>
    import { onMount } from "svelte";

    export let idValue;
    export let width="3vw", marginLeft = 'auto', marginRight='auto', marginTop='auto', marginBottom='auto';
    export let cxy = "50", r="20";

    onMount(() => {
        const loaderWrapper = document.getElementById("loader-"+idValue);
        if(width.trim() !== '') {
            loaderWrapper.style.width = width;
        }

        const spinnerWrapper = document.getElementById("spinner-"+idValue);

        if(marginBottom.trim() !== '') {
            spinnerWrapper.style.marginBottom = marginBottom;
        }

        if(marginTop.trim() !== '') {
            spinnerWrapper.style.marginTop = marginTop;
        }

        if(marginLeft.trim() !== '') {
            spinnerWrapper.style.marginLeft = marginLeft;
        }

        if(marginRight.trim() !== '') {
            spinnerWrapper.style.marginRight = marginRight;
        }
    });
</script>

<div id={"spinner-"+idValue}>
    <div id={"loader-"+idValue} class="loader">
      <svg class="circular" viewBox="25 25 50 50">
        <circle class="path" cx={cxy} cy={cxy} r={r} fill="none" stroke-width="2" stroke-miterlimit="10"/>
      </svg>
    </div>
</div>

<style>

.loader {
    position: relative;
    margin: 3vw auto;
    width: 3vw;
}
.loader::before {
    content: '';
    display: block;
}

.circular {
    animation: rotate 2s linear infinite;
    height: 100%;
    transform-origin: center center;
    width: 100%;
}

.path {
    stroke-dasharray: 1, 200;
    stroke-dashoffset: 0;
    animation: dash 1.5s ease-in-out infinite, color 6s ease-in-out infinite;
    stroke-linecap: round;
}

@keyframes rotate {
    100% {
        transform: rotate(360deg);
    }
}

@keyframes dash {
    0% {
        stroke-dasharray: 1, 200;
        stroke-dashoffset: 0;
    }
    50% {
        stroke-dasharray: 89, 200;
        stroke-dashoffset: -35px;
    }
    100% {
        stroke-dasharray: 89, 200;
        stroke-dashoffset: -124px;
    }
}

@keyframes color {
    100%,
    0% {
        stroke: red;
    }
    50% {
        stroke: blue;
    }
    80%,
    90% {
        stroke: green;
    }
}
</style>