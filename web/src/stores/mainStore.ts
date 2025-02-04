import { writable, Writable } from "svelte/store";
import fetchNUI from '../utils/fetch';

interface mainState {
  showUi: Writable<boolean>,
  uiData: Writable<any>
}

const store = () => {
  const mainStore: mainState = {
    showUi: writable(false),
    uiData: writable({})
  }

  const mainMethods = {
    closeMainUi() {
      mainStore.showUi.set(false);
      mainStore.uiData.set({});

      fetchNUI('closeUi');
    },
    showMainUi(data) {
      mainStore.showUi.set(true);
      mainStore.uiData.set(data);
    },
  }

  return {
    ...mainStore,
    ...mainMethods
  }
}

export default store();