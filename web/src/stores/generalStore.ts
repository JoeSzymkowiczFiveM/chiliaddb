import { Readable, readable } from "svelte/store";
import mainMethods from "./mainStore";

interface generalState {
  isDev: Readable<boolean>,
}

const store = () => {
  const generalStore: generalState = {
    isDev: readable(false)
  }

  const generalMethods = {
    upperCaseFirstLetter(word) {
      return word.charAt(0).toUpperCase() + word.slice(1);
    },
    filterItems(idsToFilter, arrayToFilterFrom) {
        return arrayToFilterFrom.filter((value) => {
          return !idsToFilter.includes(value.id);
        })
    },
    filterArrayByGivenObjectKey(arrayToFilter, filterKey, filterValue) {
      return arrayToFilter.filter((arrayObject) => {
        return arrayObject[filterKey] === filterValue;
      });
    },
    removeItemFromArray(array, item) {
      const index = array.indexOf(item);
      if (index > -1) { 
        array.splice(index, 1); 
      }
      return array;
    },
    removeObjectFromArrayOfObjects(array, objectKey, keyValue) {
      const itemIndex = generalMethods.getIndexOfItemFromGivenArrayByKey(array, objectKey, keyValue);
      
      if (itemIndex > -1) { 
        array.splice(itemIndex, 1); 
      }
      return array;
    },
    getIndexOfItemFromGivenArrayByKey(array, objectKey, keyValue) {
      const mappedArray = array.map((item, idx) => {
        if(item[objectKey] === keyValue) {
            return idx;
        }
      });

      const filteredArray = mappedArray.filter((item) => {
        return item !== undefined;
      });

      if(filteredArray.length < 1){
        return -1;
      }
      return filteredArray[0];
    },
    convertNumberToString(balance) {
      return balance.toLocaleString();
    },
    splitarrayInEqualChunks(array, numOfChunks) {
      let result = [];
      for (let i = numOfChunks; i > 0; i--) {
          result.push(array.splice(0, Math.ceil(array.length / i)));
      }
      return result;
    },
    handleKeyUp(data) {
        if (data.key == "Escape") {
          mainMethods.closeMainUi();
        }
    },
  }

  return {
    ...generalStore,
    ...generalMethods
  }
}

export default store();