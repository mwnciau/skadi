<script lang="ts">
import type { DynamicDataset, DynamicDatasetBelongsTo } from "../../types";
import Icon from "../components/Icon.svelte";
import { datasetFieldLabel, datasetLabel, isDynamicDataset, parseDatasetField } from "../helpers/datasets";

const {
  dataset,
  pruneBelongsTo,
  splitFields,
} : {
  dataset: DynamicDataset;
  pruneBelongsTo: () => void;
  splitFields: {label: string, value: string}[];
} = $props();


const addSplit = (e: Event & {currentTarget: EventTarget & HTMLSelectElement}) => {
  if (!isDynamicDataset(dataset)) {
    return;
  }

  const {datasetType, field, association} = parseDatasetField(dataset, e.currentTarget.value);
  let targetDataset: DynamicDataset | DynamicDatasetBelongsTo;
  if (association === "belongs_to") {
    dataset.belongs_to ??= {}
    dataset.belongs_to[datasetType] ??= {}
    targetDataset = dataset.belongs_to[datasetType];
  } else {
    targetDataset = dataset;
  }

  if (!targetDataset) {
    return;
  }
  targetDataset.split_by ??= [];
  targetDataset.split_by.push(field);

  e.currentTarget.value = "";
}

const removeSplit = (split: string, belongsToTable: string | null) => {
  if (!isDynamicDataset(dataset)) {
    return;
  }

  let targetDataset: DynamicDataset | DynamicDatasetBelongsTo = dataset;
  if (belongsToTable !== null) {
    if (!dataset.belongs_to?.[belongsToTable]) {
      return;
    }

    targetDataset = dataset.belongs_to[belongsToTable];
  }

  if (!Array.isArray(targetDataset.split_by)) {
    return;
  }

  if (targetDataset.split_by.length === 1) {
    delete targetDataset.split_by;

    if (belongsToTable !== null) {
      pruneBelongsTo();
    }
  } else {
    const index = targetDataset.split_by.indexOf(split);
    targetDataset.split_by.splice(index, 1);
  }
}
</script>

<div class="border-l-2 border-ice-700 pl-4 mt-4 py-0.5 flex flex-col gap-3">
  <p class="text-sm font-medium text-ice-700">
    Splits
  </p>
  <p class="-mt-2 text-xs text-grey-600">
    Shows a separate chart series for each unique value of the given fields
  </p>

  {#snippet splitFieldTemplate(splitField: string, belongsToTable: string | null = null)}
    <div class="flex items-center gap-1 pill pr-0.5">
      <div class="font-medium">
        {datasetFieldLabel(splitField, belongsToTable ?? dataset.type)}
      </div>
      <button
        type="button"
        class="unstyled text-night-800 hover:text-black hover:bg-night-50 p-1 cursor-pointer"
        onclick={() => removeSplit(splitField, belongsToTable)}>
        <Icon size=16 name="delete" />
      </button>
    </div>
  {/snippet}
  {#if Array.isArray(dataset.split_by)}
    <div class="flex flex-wrap gap-2">
      {#each dataset.split_by as splitField}
        {@render splitFieldTemplate(splitField)}
      {/each}
    </div>
  {/if}
  {#if dataset.belongs_to}
    {#each Object.entries(dataset.belongs_to) as [belongsToTable, belongsToDataset] (belongsToTable)}
      {#if Array.isArray(belongsToDataset.split_by) && belongsToDataset.split_by.length > 0}
        <p class="text-sm font-medium text-ice-600">
          {datasetLabel(belongsToTable)}
        </p>
        <div class="flex flex-wrap gap-2 -mt-2">
          {#each belongsToDataset.split_by as splitField}
            {@render splitFieldTemplate(splitField, belongsToTable)}
          {/each}
        </div>
      {/if}
    {/each}
  {/if}

  <label>
    <span class="sr-only">Add a split</span>
    <select
      onchange={addSplit}
      class="text-gray-600"
    >
      <option selected value="">Add a split</option>
      {#each splitFields as field}
        {#if !Array.isArray(dataset.split_by) || !dataset.split_by.includes(field.value)}
          <option value={field.value}>{field.label}</option>
        {/if}
      {/each}
    </select>
  </label>
</div>
