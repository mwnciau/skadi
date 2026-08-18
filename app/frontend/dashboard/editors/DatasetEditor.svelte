<script lang="ts">
import type {
  ChartConfig,
  Dataset, DatasetFilterOperator, FieldSchema, SchemaDatasetFilter,
} from "../../types";
import ExpandingSection from "../components/ExpandingSection.svelte";
import Filter from "../components/Filter.svelte";
import Icon from "../components/Icon.svelte";
import { databaseSchema } from "../helpers/databaseSchema";
import { isFilterUnary, isPercentageDataset, isSchemaDataset, isSqlDataset } from "../helpers/datasets";
import { formatString } from "../helpers/formatting";

const SQL_DEFAULT = `SELECT
  skadi_views.created_at as "date",
  NULL as "split",
  1 as "count"
FROM skadi_views`;

const OPERATORS = {
  boolean: ["=", "!=", "empty", "not empty"],
  date: ["=", "!=", ">", ">=", "<=", "<", "empty", "not empty"],
  number: ["=", "!=", ">", ">=", "<=", "<", "empty", "not empty"],
  one_of: ["=", "!=", "empty", "not empty"],
  string: ["=", "!=", "like", "not like", "empty", "not empty"],
};

const { canDangerouslyUseSql, chartConfig, dataset, index, startOpen = false, onDelete, onDuplicate, onMoveUp, onMoveDown }: {
  canDangerouslyUseSql: boolean;
  chartConfig: ChartConfig,
  dataset: Dataset;
  index: number;
  startOpen?: boolean;
  onDelete: () => void;
  onDuplicate: () => void;
  onMoveUp?: null | (() => void);
  onMoveDown?: null | (() => void);
} = $props();

const datasetIdOptions = $derived.by(() => {
  if (!isPercentageDataset(dataset)) {
    return [];
  }

  const datasetsOptions = chartConfig.datasets
    .filter((dataset) => {
      if (dataset.type === "percentage") {
        return false;
      }

      if (isSchemaDataset(dataset) && dataset.split_by) {
        return false;
      }

      return true;
    })
  .map((dataset) => ({
    value: dataset.id,
    label: dataset.label,
  }))

  return [
    "",
    ...datasetsOptions,
  ];
})

const types = $derived([
  ...Object.keys(databaseSchema),
  "percentage",
  "sql",
]);
const datasetSchema = $derived(databaseSchema[dataset.type])
const datasetFields = $derived<Record<string,FieldSchema>>(databaseSchema[dataset.type]?.fields ?? {});
const filterFields: string[] = $derived.by(() => {
  if (!datasetSchema) {
    return [];
  }

  return Object.entries(datasetFields)
    .flatMap(([field, config]) => config.filter ? [field] : []);
});
let splitFields: string[] = $derived.by(() => {
  if (!datasetSchema) {
    return [];
  }

  return Object.entries(datasetFields)
    .flatMap(([field, config]) => config.split ? [field] : []);
});

let confirmDelete: boolean = $state(false);

const setType = (event: Event & {currentTarget: EventTarget & HTMLSelectElement}) => {
  const newType = event.currentTarget.value as typeof dataset.type;
  if (newType === dataset.type) {
    return;
  }

  dataset.type = newType;

  const allowedKeys = [
    "id",
    "type",
    "label",
    "visible",
    "axis",
  ];
  if (isSchemaDataset(dataset)) {
    allowedKeys.push("filters");
  }

  for (const key of Object.keys(dataset)) {
    if (!allowedKeys.includes(key)) {
      delete (dataset as Record<string, unknown>)[key];
    }
  }

  if (isSchemaDataset(dataset) && Array.isArray(dataset.filters)) {
    // Remove any filters that aren't compatible
    for (let i = 0; i < dataset.filters.length; i++) {
      if (!isFilterValid(dataset.filters[i])) {
        dataset.filters.splice(i, 1)

        // Decrement the loop index because we're removing an element
        i--;
      }
    }
  }

  if (isSqlDataset(dataset)) {
    dataset.sql = SQL_DEFAULT;
  }
}

const isFilterValid = (filter: SchemaDatasetFilter) => {
  // Check whether the field actually exists in the schema
  if (!filterFields.includes(filter.field)) {
    return false;
  }

  const fieldSchema = datasetFields[filter.field];

  // Check the operator is compatible
  if (!OPERATORS[fieldSchema.type ?? "string"]?.includes(filter.operator)) {
    return false;
  }

  // Simple case when the operator doesn't require a value
  if (isFilterUnary(filter)) {
    // These don't have a value so it's a simple check
    return !("value" in filter);
  }

  switch (fieldSchema.type) {
    case "one_of":
      return fieldSchema.options?.some((option) => {
        if (typeof option === "string") {
          return option === filter.value;
        }

        return option.value === filter.value;
      });
    case "date":
      return typeof filter.value === "string" && filter.value.match(/^\d{4}-[01]\d-[0-3]\d$/);
    default:
      return typeof filter.value === fieldSchema.type;
  }
}

const DEFAULT_VALUES = {
  "boolean": true,
  "date": (new Date()).toISOString().substring(0, 10),
  "number": 0,
  "one_of": "",
  "string": "",
};

const defaultFilterValueForField = (fieldSchema: FieldSchema) => {
  if (fieldSchema.type === "one_of" && fieldSchema.options) {
    const firstOption = fieldSchema.options[0];

    return typeof firstOption === "string" ? firstOption : firstOption.value;
  }

  return DEFAULT_VALUES[fieldSchema.type ?? "string"];
}

const addFilter = (e: Event & {currentTarget: EventTarget & HTMLSelectElement}) => {
  if (!isSchemaDataset(dataset)) {
    return;
  }

  const field = e.currentTarget.value;
  const fieldSchema = datasetFields[field];

  dataset.filters ??= [];
  dataset.filters.push({field: field, operator: "=", value: defaultFilterValueForField(fieldSchema)});

  e.currentTarget.value = "";
}

const setFilterOperator = (index: number, event: Event & {currentTarget: EventTarget & HTMLSelectElement}) => {
  if (!isSchemaDataset(dataset) || !dataset.filters) {
    return;
  }
  const newOperator = event.currentTarget.value as DatasetFilterOperator;
  const filter = dataset.filters[index];
  const fieldSchema = datasetFields[filter.field];

  const wasUnary = isFilterUnary(filter);
  filter.operator = newOperator;

  if (isFilterUnary(filter)) {
    delete (filter as Record<string,unknown>).value;
  } else if (wasUnary || filter.value === undefined) {
    filter.value = defaultFilterValueForField(fieldSchema);
  }
}

const deleteFilter = (index: number) => {
  if (!isSchemaDataset(dataset) || !Array.isArray(dataset.filters)) {
    return;
  }

  if (dataset.filters.length === 1) {
    delete dataset.filters;
  } else {
    dataset.filters.splice(index, 1);
  }
}

const addSplit = (e: Event & {currentTarget: EventTarget & HTMLSelectElement}) => {
  if (!isSchemaDataset(dataset)) {
    return;
  }

  if (Array.isArray(dataset.split_by)) {
    dataset.split_by.push(e.currentTarget.value);
  } else {
    dataset.split_by = [e.currentTarget.value];
  }

  e.currentTarget.value = "";
}

const removeSplit = (split: string) => {
  if (!isSchemaDataset(dataset) || !Array.isArray(dataset.split_by)) {
    return;
  }

  if (dataset.split_by.length === 1) {
    delete dataset.split_by;

    return;
  }

  const index = dataset.split_by.indexOf(split);
  dataset.split_by.splice(index, 1);
}

let expandingSection: ReturnType<typeof ExpandingSection>;
const duplicate = () => {
  onDuplicate();
  expandingSection?.close();
}
</script>

<ExpandingSection bind:this={expandingSection} wrapperClass="border-night-700" {startOpen}>
  {#snippet title(open)}
    <p class="text-sm font-semibold text-night-700 group-hover:text-night-800">
      {#if open}
        Dataset {index + 1}
      {:else}
        <span class="capitalize">{dataset.type}</span> dataset: {dataset.label}
      {/if}
    </p>
  {/snippet}

  <label>
    Label
    <input type="text" bind:value={dataset.label} />
    <span class="help-text">Splits can be incorporated into the label using <code>%1</code>, <code>%2</code>, etc. or with a default value if empty using <code>%1(none)</code></span>
  </label>

  <label>
    Type
    <select onchange="{setType}" value={dataset.type}>
      {#each types as type (type)}
        <option value={type}>{formatString(type)}</option>
      {/each}
    </select>
  </label>

  {#if chartConfig.type !== "table"}
    <Filter type="switch" leftValue={false} model={dataset} key="visible">
      Show on chart
    </Filter>

    {#if dataset.visible !== false}
      <Filter
        type="switch"
        leftLabel="Left"
        rightLabel="Right"
        rightValue="right"
        model={dataset}
        key="axis"
      >
        Axis
      </Filter>
    {/if}

    {#if isSchemaDataset(dataset) && splitFields.length > 0}
      <div class="border-l-2 border-ice-600 pl-4 mt-4 py-0.5 flex flex-col gap-3">
        <p class="text-sm font-medium text-ice-600">
          Splits
        </p>
        <p class="text-xs text-grey-600">
          Shows a separate chart series for each unique value of the given fields
        </p>
        {#if Array.isArray(dataset.split_by)}
          <div class="flex flex-wrap gap-2">
            {#each dataset.split_by as splitField}
              <div class="flex items-center gap-1">
                <div class="font-medium">
                  {datasetFields[splitField]?.label ?? formatString(splitField)}
                </div>
                <button
                  type="button"
                  class="unstyled text-night-800 hover:text-black hover:bg-night-50 p-1 cursor-pointer"
                  onclick={() => removeSplit(splitField)}>
                  <Icon size=16 name="delete" />
                </button>
              </div>
            {/each}
          </div>
        {/if}

        <label>
          <span class="sr-only">Add a split</span>
          <select
            onchange={addSplit}
            class="text-gray-600"
          >
            <option selected value="">Add a split</option>
            {#each splitFields as field}
              {#if !Array.isArray(dataset.split_by) || !dataset.split_by.includes(field)}
                <option value={field}>{datasetFields[field]?.label ?? formatString(field)}</option>
              {/if}
            {/each}
          </select>
        </label>
      </div>
    {/if}
  {/if}

  {#if isPercentageDataset(dataset)}
    <Filter
      type="select"
      model={dataset}
      key="numerator"
      selectOptions={datasetIdOptions}
      description="The dataset you are using for your target, e.g. a specific page view or event."
    >
      Numerator
    </Filter>

    <Filter
      type="select"
      model={dataset}
      key="denominator"
      selectOptions={datasetIdOptions}
      description="The dataset you are using for comparison, e.g. the number of visits."
    >
      Denominator
    </Filter>
  {:else if isSqlDataset(dataset)}
    <Filter
      type="textarea"
      model={dataset}
      key="sql"
      class="font-mono text-red-800 bg-red-50/50 p-1 border border-red-800"
      rows="10"
      readonly={!canDangerouslyUseSql}
    >
      SQL Query

      {#snippet description()}
        {#if chartConfig.type !== "table"}
          <span class="help-text">
            Note: your query must return three columns: <code>date</code>, <code>split</code>, and <code>count</code>. <code>split</code> can be <code>NULL</code>
          </span>
        {/if}
      {/snippet}
    </Filter>
  {:else}
    <div class="border-l-2 border-ice-600 pl-4 mt-4 py-0.5 flex flex-col gap-3">
      <p class="text-sm font-medium text-ice-600">
        Filters
      </p>

      <div class="grid grid-cols-[auto_4rem_1fr_auto] gap-1 items-center">
        {#each (dataset.filters ?? []) as filter, index}
          {@const fieldConfig = datasetFields[filter.field]}
          {@const fieldLabel = fieldConfig?.label ?? formatString(filter.field)}

          <span>{fieldLabel}:</span>
          <label class="h-full {isFilterUnary(filter) ? "col-span-2 w-max" : ""}">
            <span class="sr-only">operator</span>
            <select onchange={(e) => setFilterOperator(index, e)}>
              {#each OPERATORS[fieldConfig.type ?? "string"] as operator}
                <option>{operator}</option>
              {/each}
            </select>
          </label>
          {#if !isFilterUnary(filter)}
            {#if fieldConfig.type === "boolean"}
              <Filter
                type="switch"
                model={filter}
                leftLabel={fieldConfig.leftLabel}
                leftValue={fieldConfig.leftValue === undefined ? false : fieldConfig.leftValue}
                rightLabel={fieldConfig.rightLabel}
                rightValue={fieldConfig.rightValue === undefined ? true : fieldConfig.rightValue}
                key="value"
                class="ml-1"
              >
                <span class="sr-only">{fieldLabel}</span>
              </Filter>
            {:else if fieldConfig.type === "one_of"}
              <Filter
                type="select"
                model={filter}
                key="value"
                selectOptions={fieldConfig.options}
                class="w-max"
               allowEmpty={true}
              >
                <span class="sr-only">{fieldLabel}</span>
              </Filter>
            {:else}
              <Filter type={fieldConfig.type ?? "string"} model={filter} key="value" class="w-full" allowEmpty={true} showClear={!fieldConfig.type || fieldConfig.type === "string"}>
                <span class="sr-only">{fieldLabel}</span>
              </Filter>
            {/if}
          {/if}

          <button
            type="button"
            class="unstyled text-night-800 hover:text-black hover:bg-night-50 p-2 cursor-pointer"
            onclick={() => deleteFilter(index)}
          >
            <Icon name="delete" />
          </button>

          {#if fieldConfig.description}
            <p class="help-text -mt-1 col-span-4">{fieldConfig.description}</p>
          {/if}
        {/each}
      </div>

      <label class="{dataset.filters?.length ? "mt-4" : ""}">
        <span class="sr-only">Add a filter</span>
        <select
          onchange={addFilter}
          class="text-gray-600"
        >
          <option selected value="">Add a filter</option>
          {#each filterFields as field}
            <option value={field}>{datasetFields[field]?.label ?? formatString(field)}</option>
          {/each}
        </select>
      </label>
    </div>
  {/if}

  <div class="flex flex-row gap-2 mt-4">
    {#if dataset.type !== "sql" || canDangerouslyUseSql}
      <!-- While technically allowed by the validation, there's no point in duplicating the dataset because it cannot be changed -->
      <button type="button" class="sm" onclick={duplicate}>Duplicate</button>
    {/if}
    {#if onMoveUp !== null }
      <button type="button" class="sm px-1" onclick={onMoveUp}><Icon name="chevron_up" size={24} /></button>
    {/if}
    {#if onMoveDown !== null }
      <button type="button" class="sm px-1" onclick={onMoveDown}><Icon name="chevron_down" size={24} /></button>
    {/if}

    {#if chartConfig.datasets.length > 1}
      {#if confirmDelete}
        <button type="button" class="sm bg-dawn-100 ml-auto" onclick={onDelete}>Yes, delete this dataset</button>
      {:else}
        <button type="button" class="sm bg-dawn-100 ml-auto" onclick={() => (confirmDelete = true)}>Delete</button>
      {/if}
    {/if}
  </div>
</ExpandingSection>
