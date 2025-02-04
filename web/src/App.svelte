<script lang="ts">
  import { EventHandler } from './utils/eventHandler';
  import generalStore from './stores/generalStore';
  import mainStore from './stores/mainStore';
  import Base from './components/base/Base.svelte';
  import { dropdownValuesArrayData } from './stores/devData';

  EventHandler();
  
  document.onkeyup = generalStore.handleKeyUp;

  let { isDev } = generalStore;
  
  let { showUi } = mainStore;

  if($isDev) {
    if($showUi) {
      mainStore.showMainUi(dropdownValuesArrayData);
    }
  }
</script>

{#if $showUi}
  <Base />
{/if}