import { onMount, onDestroy } from "svelte";
import mainMethods from "../stores/mainStore";

interface nuiMessage {
  data: {
    action: string,
    topic?: string,
    [key: string]: any,
  },
}

export function EventHandler() {
  function mainEvent(event: nuiMessage) {
    switch (event.data.action) {
      case "openJsonUi":
        mainMethods.showMainUi(event.data.data);
        break;
      case "closeJsonUi":
        mainMethods.closeMainUi();
        break;
    }
  }

  onMount(() => window.addEventListener("message", mainEvent));
  onDestroy(() => window.removeEventListener("message", mainEvent));
}
