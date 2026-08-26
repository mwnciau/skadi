<script lang="ts">
import type { BinarySchemaDatasetFilter, ChartConfig, Dataset, DatasetSchema, SchemaDatasetFilter, } from "../../types";
import ExpandingSection from "../components/ExpandingSection.svelte";
import Filter from "../components/Filter.svelte";
import Icon from "../components/Icon.svelte";
import Switch from "../components/Switch.svelte";
import { databaseSchema } from "../helpers/databaseSchema";
import {
  countDatasetOwner,
  datasetLabel,
  isDynamicDataset,
  isFilterValid,
  isPercentageDataset,
  isSqlDataset,
} from "../helpers/datasets";
import { formatString } from "../helpers/formatting";
import DatasetFiltersEditor from "./DatasetFiltersEditor.svelte";
import DatasetSelectEditor from "./DatasetSelectEditor.svelte";
import DatasetSplitEditor from "./DatasetSplitEditor.svelte";

const SQL_DEFAULT = `SELECT
  skadi_views.created_at as "date",
  NULL as "split",
  1 as "count"
FROM skadi_views`;

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

      if (isDynamicDataset(dataset) && dataset.split_by) {
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
  ...(chartConfig.type === "table" ? [] : ["percentage"]),
  "sql",
]);
const datasetSchema = $derived<DatasetSchema | undefined>(databaseSchema[dataset.type]);

type SelectOptions = {label: string, value: string}[];
const derivedFields : {
  filter: SelectOptions;
  select: SelectOptions;
  split: SelectOptions;
} = $derived.by(() => {
  if (!datasetSchema) {
    return {filter: [], select: [], split: []};
  }
  const datasetFields = databaseSchema[dataset.type]?.fields ?? {};

  const filterFields: SelectOptions = [];
  const selectFields: SelectOptions = [];
  const splitFields: SelectOptions = [];

  for (const [field, config] of Object.entries(datasetFields)) {
    const option = {label: config.label ?? formatString(field), value: field};

    if (config.filter) {
      filterFields.push(option);
    }
    if (config.select) {
      selectFields.push(option);
    }
    if (config.split) {
      splitFields.push(option);
    }
  }

  if (Array.isArray(datasetSchema.belongs_to)) {
    for (const belongsToTable of datasetSchema.belongs_to) {
      const belongsToSchema = databaseSchema[belongsToTable];
      if (!belongsToSchema?.fields) {
        continue;
      }

      for (const [field, config] of Object.entries(belongsToSchema.fields)) {
        const option = {
          label: `${belongsToSchema.label ?? formatString(belongsToTable)}: ${config.label ?? formatString(field)}`,
          value: `${belongsToTable}.${field}`
        };

        if (config.filter) {
          filterFields.push(option);
        }
        if (config.select) {
          selectFields.push(option);
        }
        if (config.split) {
          splitFields.push(option);
        }
      }
    }
  }

  return {filter: filterFields, select: selectFields, split: splitFields};
});

let counts: {label: string, value: string}[] = $derived.by(() => {
  if (!isDynamicDataset(dataset) || chartConfig.type === "table" || !datasetSchema) {
    return [];
  }

  let counts = [
    {label: datasetSchema.counts?.[dataset.type]?.label ?? formatString(dataset.type), value: dataset.type},
  ];
  for (const [count, countConfig] of Object.entries(datasetSchema.counts ?? {})) {
    if (count === dataset.type) {
      continue;
    }

    counts.push({label: countConfig.label ?? formatString(count), value: count});
  }

  if (Array.isArray(datasetSchema.belongs_to)) {
    for (const belongsToTable of datasetSchema.belongs_to) {
      const belongsToSchema = databaseSchema[belongsToTable];

      counts.push({label: belongsToSchema?.counts?.[belongsToTable]?.label ?? formatString(belongsToTable), value: belongsToTable});
      for (const [count, countConfig] of Object.entries(belongsToSchema?.counts ?? {})) {
        if (count === belongsToTable) {
          continue;
        }

        counts.push({label: countConfig.label ?? formatString(count), value: count});
      }
    }
  }

  return counts;
});

let confirmDelete: boolean = $state(false);

const setType = (event: Event & {currentTarget: EventTarget & HTMLSelectElement}) => {
  const newType = event.currentTarget.value as typeof dataset.type;
  if (newType === dataset.type || (chartConfig.type === "table" && dataset.type === "percentage")) {
    return;
  }
  const oldType = dataset.type;

  dataset.type = newType;

  const allowedKeys = [
    "id",
    "type",
    "label",
    "visible",
    "axis",
  ];
  if (isDynamicDataset(dataset)) {
    allowedKeys.push("filters", "belongs_to");

    if (chartConfig.type === "table") {
      allowedKeys.push("selects");
    } else {
      allowedKeys.push("count_by", "split_by");
    }
  }

  for (const key of Object.keys(dataset)) {
    if (!allowedKeys.includes(key)) {
      delete (dataset as Record<string, unknown>)[key];
    }
  }

  if (isDynamicDataset(dataset)) {
    if (Array.isArray(dataset.filters)) {
      // Remove any filters that aren't compatible
      for (let i = 0; i < dataset.filters.length; i++) {
        if (!datasetSchema || !isFilterValid(datasetSchema, dataset.filters[i] as SchemaDatasetFilter)) {
          dataset.filters.splice(i, 1)

          // Decrement the loop index because we're removing an element
          i--;
        }
      }
    }

    // Ensure the count_by is still valid
    if (dataset.count_by) {
      // If counting by the old default value, switch to the new default value
      if (dataset.count_by === oldType) {
        dataset.count_by = dataset.type;
      }
      // Otherwise, if we can't find the count in the list of valid counts, switch to the default
      else if (!counts.find((count) => count.value === dataset.count_by)) {
        dataset.count_by = dataset.type;
      }
    }

    // Remove any now invalid selects
    if (dataset.selects) {
      for (let i = 0; i < dataset.selects.length; i++) {
        const select = dataset.selects[i] as string;

        // Selects with a dot are selects from other datasets
        if (select.includes(".")) {
          const [selectDatasetType, field] = select.split(".", 2) as [string, string];

          // If the field dataset is the new type, we can just delete the type prefix, checking for duplicates
          if (selectDatasetType === newType && !dataset.selects.includes(field)) {
            dataset.selects[i] = field;
            continue;
          }
          // Otherwise, we check if the dataset can still be joined to
          else if (selectDatasetType && datasetSchema?.belongs_to?.includes(selectDatasetType)) {
            continue;
          }
        }
        // Selects without a dot are from this dataset so we check if it's selectable
        else if (datasetSchema?.fields[select]?.select) {
            continue;
        }

        // The select is no longer valid, so we remove it
        dataset.selects.splice(i, 1)

        // Decrement the loop index because we're removing an element
        i--;
      }

      if (dataset.selects.length === 0) {
        delete dataset.selects;
      }
    }

    // Remove any now invalid splits
    if (dataset.split_by) {
      for (let i = 0; i < dataset.split_by.length; i++) {
        const split = dataset.split_by[i] as string;

        // Check if the split is valid in the new dataset
        if (datasetSchema?.fields[split]?.split) {
            continue;
        }

        // The split_by is no longer valid, so we remove it
        dataset.split_by.splice(i, 1)

        // Decrement the loop index because we're removing an element
        i--;
      }

      if (dataset.split_by.length === 0) {
        delete dataset.split_by;
      }
    }

    // Move any splits and filters valid from the belongs to dataset
    if (dataset.belongs_to?.[newType]) {
      if (Array.isArray(dataset.belongs_to[newType].filters)) {
        dataset.filters ??= [];

        for (const filter of dataset.belongs_to[newType].filters) {
          // Prevent identical filters being pushed to the dataset
          if (!dataset.filters.find(f => f.field === filter.field && f.operator === filter.operator && (f as BinarySchemaDatasetFilter).value === (filter as BinarySchemaDatasetFilter).value)){
            dataset.filters.push(filter);
          }
        }
      }
      if (Array.isArray(dataset.belongs_to[newType].split_by)) {
        dataset.split_by ??= [];

        for (const split of dataset.belongs_to[newType].split_by) {
          if (!dataset.split_by.includes(split)){
            dataset.split_by.push(split);
          }
        }
      }

      delete dataset.belongs_to[newType];
    }

    pruneBelongsTo();
  }

  if (isSqlDataset(dataset)) {
    dataset.sql = SQL_DEFAULT;
  }
}

const setCount = (event: Event & {currentTarget: EventTarget & HTMLSelectElement}) => {
  const newCount = event.currentTarget.value;
  if (!isDynamicDataset(dataset) || dataset.count_by === newCount) {
    return;
  }

  dataset.count_by = newCount;

  const countDatasetType = countDatasetOwner(dataset.type, newCount);

  // Ensure the found dataset is joined to
  if (countDatasetType && countDatasetType !== dataset.type) {
    dataset.belongs_to ??= {};
    dataset.belongs_to[countDatasetType] ??= {};
  }

  pruneBelongsTo();
}

const toggleDatasetRequired = (datasetType: string) => {
  if (!isDynamicDataset(dataset)) {
    return;
  }

  if (dataset.belongs_to?.[datasetType]?.required) {
    delete dataset.belongs_to[datasetType].required;

    pruneBelongsTo();
  } else {
    dataset.belongs_to ??= {};
    dataset.belongs_to[datasetType] ??= {};
    dataset.belongs_to[datasetType].required = true;
  }
}

const pruneBelongsTo = () => {
  if (!isDynamicDataset(dataset)) {
    return;
  }

  let neededDatasets = new Set<string>();

  if (dataset.count_by) {
    const countDatasetType = countDatasetOwner(dataset.type, dataset.count_by);
    if (countDatasetType && countDatasetType !== dataset.type) {
      neededDatasets.add(countDatasetType);
    }
  }

  if (dataset.selects) {
    for (const select of dataset.selects) {
      if (select.includes(".")) {
        const [table, _] = select.split(".", 2) as [string, string];
        neededDatasets.add(table);
      }
    }
  }

  if (neededDatasets.size === 0 && !dataset.belongs_to) {
    return;
  }

  dataset.belongs_to ??= {};

  // Check if any of the existing datasets are unnecessary
  for (const [table, belongsToDataset] of Object.entries(dataset.belongs_to)) {
    if (
      datasetSchema?.belongs_to?.includes(table)
      && (
        neededDatasets.has(table)
        || belongsToDataset.required !== undefined
        || belongsToDataset.split_by?.length
        || belongsToDataset.filters?.length
      )
    ) {
      continue;
    }

    delete dataset.belongs_to[table];
  }

  // We need some datasets because of the selects, so ensure they exist
  for (const table of neededDatasets) {
    dataset.belongs_to[table] ??= {};
  }

  // Clean up the dataset belongs_to if it's no longer needed
  if (Object.keys(dataset.belongs_to).length === 0) {
    delete dataset.belongs_to;
  }
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

  <div class="sm:grid grid-cols-2 gap-x-2 gap-y-4">
    <label class="only:col-span-2">
      Type
      <select onchange="{setType}" value={dataset.type}>
        {#each types as type (type)}
          <option value={type}>{formatString(type)}</option>
        {/each}
      </select>
    </label>

    {#if isDynamicDataset(dataset) && counts.length > 1 && chartConfig.type !== "table"}
      <label>
        Count by
        <select onchange="{setCount}" value={dataset.count_by ?? dataset.type}>
          {#each counts as count (count)}
            <option value={count.value}>{count.label}</option>
          {/each}
        </select>
      </label>
    {/if}
  </div>

  {#if chartConfig.type === "table"}
    {#if isDynamicDataset(dataset) && derivedFields.select.length > 0}
      <DatasetSelectEditor
        {dataset}
        {pruneBelongsTo}
        selectFields={derivedFields.select}
      />
    {/if}
  {:else}
    <div class="sm:grid grid-cols-[auto_1fr] gap-4 sm:gap-12">
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
    </div>

    {#if isDynamicDataset(dataset)}
      {#if derivedFields.split.length > 0}
        <DatasetSplitEditor
          {dataset}
          {pruneBelongsTo}
          splitFields={derivedFields.split}
        />
      {/if}
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
    <DatasetFiltersEditor
      {dataset}
      {pruneBelongsTo}
      filterFields={derivedFields.filter}
    />

    {#if datasetSchema?.belongs_to}
      <div class="mt-4 flex flex-wrap gap-y-2 gap-x-4">
        <p class="text-sm font-medium text-ice-700 mb-0.5 basis-full">
          Linked tables
        </p>
        {#each datasetSchema.belongs_to as belongsToTable}
          {@const required = dataset.belongs_to?.[belongsToTable]?.required ?? false}
          <label class="flex flex-row items-center gap-2 font-normal pill pl-3 pr-1 {required ? "bg-ice-50/50" : "bg-gray-50/50"}">
            <span class="text-sm font-medium">{datasetLabel(belongsToTable)}</span>
            <span class="ml-3 text-gray-500 text-xs font-normal">required?</span>
            <Switch
              value={required}
              onToggle={() => toggleDatasetRequired(belongsToTable)}
            />
          </label>
        {/each}
      </div>
    {/if}
  {/if}

  <div class="flex flex-row gap-2 mt-4">
    {#if (dataset.type !== "sql" || canDangerouslyUseSql) && chartConfig.type !== "table"}
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
