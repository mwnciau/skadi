<script lang="ts">
import type { DynamicDataset } from "../../types";
import Icon from "../components/Icon.svelte";
import { datasetLabel, isDynamicDataset, parseDatasetField } from "../helpers/datasets";
import { formatString } from "../helpers/formatting";

const {
  dataset,
  pruneBelongsTo,
  selectFields,
} : {
  dataset: DynamicDataset;
  pruneBelongsTo: () => void;
  selectFields: {label: string, value: string}[];
} = $props();


const addSelect = (e: Event & {currentTarget: EventTarget & HTMLSelectElement}) => {
  if (!isDynamicDataset(dataset)) {
    return;
  }

  const select = e.currentTarget.value;

  dataset.selects ??= [];
  dataset.selects.push(select);

  // Ensure adding the table adds the belongs to
  const {datasetType, association} = parseDatasetField(dataset, select);
  if (association === "belongs_to") {
    dataset.belongs_to ??= {}
    dataset.belongs_to[datasetType] ??= {}
  }

  e.currentTarget.value = "";
}

const removeSelect = (select: string) => {
  if (!isDynamicDataset(dataset) || !Array.isArray(dataset.selects)) {
    return;
  }

  if (dataset.selects.length === 1) {
    delete dataset.selects;
  } else {
    const index = dataset.selects.indexOf(select);
    dataset.selects.splice(index, 1);
  }

  // If the select option has a dot, then this is a belongs_to field
  if (select.includes(".")) {
    pruneBelongsTo();
  }
}
</script>

<div class="border-l-2 border-ice-700 pl-4 mt-4 py-0.5 flex flex-col gap-3">
  <p class="text-sm font-medium text-ice-700">
    Selected fields
  </p>
  <p class="text-xs text-grey-600">
    If no fields are selected, all fields in the dataset will be returned
  </p>

  {#if Array.isArray(dataset.selects)}
    <div class="flex flex-wrap gap-2">
      {#each dataset.selects as selectField}
        {@const {association, field, fieldSchema, datasetType} = parseDatasetField(dataset, selectField)}
        <div class="flex items-center gap-1 pill pr-0.5">
          <div class="font-medium">
            {#if association === "belongs_to"}
              {datasetLabel(datasetType)}:
            {/if}
            {fieldSchema?.label ?? formatString(field)}
          </div>
          <button
            type="button"
            class="unstyled text-night-800 hover:text-black hover:bg-night-50 p-1 cursor-pointer"
            onclick={() => removeSelect(selectField)}>
            <Icon size=16 name="delete" />
          </button>
        </div>
      {/each}
    </div>
  {/if}

  <label>
    <span class="sr-only">Add a select</span>
    <select
      onchange={addSelect}
      class="text-gray-600"
    >
      <option selected value="">Add a select</option>
      {#each selectFields as field}
        {#if !Array.isArray(dataset.selects) || !dataset.selects.includes(field.value)}
          <option value={field.value}>{field.label}</option>
        {/if}
      {/each}
    </select>
  </label>
</div>
