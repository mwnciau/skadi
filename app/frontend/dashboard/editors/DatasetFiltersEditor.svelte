<script lang="ts">
import type { DynamicDataset, DynamicDatasetBelongsTo } from "../../types";
import { datasetLabel, defaultFilterValueForField, isDynamicDataset, parseDatasetField } from "../helpers/datasets";
import DatasetFilterEditor from "./DatasetFilterEditor.svelte";

const {
  dataset,
  pruneBelongsTo,
  filterFields,
} : {
  dataset: DynamicDataset;
  pruneBelongsTo: () => void;
  filterFields: {label: string, value: string}[];
} = $props();

const hasFilters = $derived.by(() => {
  if (dataset.filters?.length) {
    return true;
  }

  if (!dataset.belongs_to) {
    return false;
  }

  // Check if any of the belongs_to datasets have defined filters
  return Object.values(dataset.belongs_to).some((belongs_to) => belongs_to.filters?.length)
})

const addFilter = (e: Event & {currentTarget: EventTarget & HTMLSelectElement}) => {
  if (!isDynamicDataset(dataset)) {
    return;
  }

  const {field, datasetType, fieldSchema, association} = parseDatasetField(dataset, e.currentTarget.value);
  let targetDataset: DynamicDataset | DynamicDatasetBelongsTo = dataset;
  if (association === "belongs_to") {
    dataset.belongs_to ??= {}
    dataset.belongs_to[datasetType] ??= {}
    targetDataset = dataset.belongs_to[datasetType];
  }

  if (!fieldSchema) {
    return;
  }

  targetDataset.filters ??= [];
  targetDataset.filters.push({field: field, operator: "=", value: defaultFilterValueForField(fieldSchema)});

  e.currentTarget.value = "";
}

const removeFilter = (index: number, belongsToTable: string | null) => {
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

  if (!Array.isArray(targetDataset.filters)) {
    return;
  }

  if (targetDataset.filters.length === 1) {
    delete targetDataset.filters;

    if (belongsToTable !== null) {
      pruneBelongsTo();
    }
  } else {
    targetDataset.filters.splice(index, 1);
  }
}
</script>

<div class="border-l-2 border-ice-700 pl-4 mt-4 py-0.5 flex flex-col gap-3">
  <p class="text-sm font-medium text-ice-700">
    Filters
  </p>

  {#if hasFilters}
    <div class="grid grid-cols-[auto_4rem_1fr_auto] gap-1 items-center">
      {#each (dataset.filters ?? []) as filter, index}
        <DatasetFilterEditor
          {dataset}
          datasetType={dataset.type}
          {filter}
          {index}
          removeFilter={() => removeFilter(index, null)}
        />
      {/each}
      {#if dataset.belongs_to}
        {#each Object.entries(dataset.belongs_to) as [belongsToTable, belongsToDataset] (belongsToTable)}
          {#if belongsToDataset.filters?.length}
            <p class="text-sm font-medium text-ice-600 mt-2 col-span-4">
              {datasetLabel(belongsToTable)}
            </p>
            {#each belongsToDataset.filters as filter, index}
              <DatasetFilterEditor
                dataset={belongsToDataset}
                datasetType={belongsToTable}
                {filter}
                {index}
                removeFilter={() => removeFilter(index, belongsToTable)}
              />
            {/each}
          {/if}
        {/each}
      {/if}
    </div>
  {/if}

  <label class="{hasFilters ? "mt-4" : ""}">
    <span class="sr-only">Add a filter</span>
    <select
      onchange={addFilter}
      class="text-gray-600"
    >
      <option selected value="">Add a filter</option>
      {#each filterFields as field}
        <option value={field.value}>{field.label}</option>
      {/each}
    </select>
  </label>
</div>
