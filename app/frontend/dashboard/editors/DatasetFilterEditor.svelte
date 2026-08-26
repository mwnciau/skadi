<script lang="ts">
import type { DatasetFilterOperator, DynamicDataset, DynamicDatasetBelongsTo, SchemaDatasetFilter } from "../../types";
import Filter from "../components/Filter.svelte";
import Icon from "../components/Icon.svelte";
import { databaseSchema } from "../helpers/databaseSchema";
import {
  datasetFieldLabel,
  datasetFilterOperators,
  defaultFilterValueForField,
  isFilterUnary
} from "../helpers/datasets";

const {
  dataset,
  // For belongs_to datasets, the type isn't a property on the dataset so we need to pass it in
  datasetType,
  filter,
  index,
  removeFilter,
} : {
  dataset: DynamicDataset | DynamicDatasetBelongsTo;
  datasetType: string;
  filter: SchemaDatasetFilter;
  index: number;
  removeFilter: () => void;
} = $props();

const fieldSchema = $derived(databaseSchema[datasetType]?.fields?.[filter.field])

const setFilterOperator = (index: number, event: Event & {currentTarget: EventTarget & HTMLSelectElement}) => {
  if (!dataset.filters) {
    return;
  }
  const newOperator = event.currentTarget.value as DatasetFilterOperator;
  const filter = dataset.filters[index] as SchemaDatasetFilter;

  const wasUnary = isFilterUnary(filter);
  filter.operator = newOperator;

  if (isFilterUnary(filter)) {
    delete (filter as Record<string,unknown>).value;
  } else if (wasUnary || filter.value === undefined) {
    filter.value = fieldSchema ? defaultFilterValueForField(fieldSchema) : "";
  }
}

</script>

<span>{datasetFieldLabel(filter.field, datasetType)}:</span>
<label class="h-full {isFilterUnary(filter) ? "col-span-2 w-max" : ""}">
  <span class="sr-only">operator</span>
  <select onchange={(e) => setFilterOperator(index, e)} value={filter.operator}>
    {#each datasetFilterOperators(fieldSchema) as operator}
      <option>{operator}</option>
    {/each}
  </select>
</label>
{#if !isFilterUnary(filter)}
  {#if fieldSchema?.type === "boolean"}
    <Filter
      type="switch"
      model={filter}
      leftLabel={fieldSchema.leftLabel}
      leftValue={fieldSchema.leftValue === undefined ? false : fieldSchema.leftValue}
      rightLabel={fieldSchema.rightLabel}
      rightValue={fieldSchema.rightValue === undefined ? true : fieldSchema.rightValue}
      key="value"
      class="ml-1"
    >
      <span class="sr-only">{datasetFieldLabel(filter.field, datasetType)} value</span>
    </Filter>
  {:else if fieldSchema?.type === "one_of"}
    <Filter
      type="select"
      model={filter}
      key="value"
      selectOptions={fieldSchema.options}
      class="w-max"
     allowEmpty={true}
    >
      <span class="sr-only">{datasetFieldLabel(filter.field, datasetType)} value</span>
    </Filter>
  {:else}
    <Filter type={fieldSchema?.type ?? "string"} model={filter} key="value" class="w-full" allowEmpty={true} showClear={!fieldSchema?.type || fieldSchema?.type === "string"}>
      <span class="sr-only">{datasetFieldLabel(filter.field, datasetType)} value</span>
    </Filter>
  {/if}
{/if}

<button
  type="button"
  class="unstyled text-night-800 hover:text-black hover:bg-night-50 p-2 cursor-pointer"
  onclick={removeFilter}
>
  <Icon name="delete" />
</button>

{#if fieldSchema?.description}
  <p class="help-text -mt-1 mb-1 col-span-4">{fieldSchema.description}</p>
{/if}