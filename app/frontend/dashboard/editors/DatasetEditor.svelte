<script lang="ts">
import type {
  ChartConfig,
  Dataset,
} from "../../types";
import Icon from "../components/Icon.svelte";
import Filter from "../components/Filter.svelte";
import { datasetSchema } from "../helpers/datasetSchema";
import { untrack } from "svelte";
import ExpandingSection from "../components/ExpandingSection.svelte";

const SQL_DEFAULT = `SELECT
  skadi_views.created_at as "date",
  NULL as "split",
  1 as "count"
FROM skadi_views`;

const formatString = (string: string) => {
  return string
    // Replace underscores with spaces
    .replace(/_/g, " ")
    // Capitalise the first letter
    .replace(/^[a-z]/, (letter) => letter.toLocaleUpperCase())
    // A few QoL replacements
    .replace(/^Sql/, "SQL")
    .replace(/^Utm/, "UTM");
}

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
  if (dataset.type !== "percentage") {
    return [];
  }

  const datasetsOptions = chartConfig.datasets
    .filter((dataset) => {
      if (dataset.type === "percentage") {
        return false;
      }

      if (dataset.split_by) {
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
  ...Object.keys(datasetSchema),
  "percentage",
  "sql",
]);
const fields = $derived<Record<string,unknown> | undefined>(datasetSchema[dataset.type]?.fields);
const filterFields = $derived.by(() => {
  if (dataset.type == "sql") {
    return {
      sql: {type: "sql"},
    };
  }

  if (dataset.type == "percentage") {
    return {
      numerator: {
        description: "The dataset you are using for your target, e.g. a specific page view or event.",
        options: datasetIdOptions,
      },
      denominator: {
        description: "The dataset you are using for comparison, e.g. the number of visits.",
        options: datasetIdOptions,
      },
    };
  }

  if (fields) {
    return Object.fromEntries(
      Object.entries(fields)
        .filter(([_field, config]) => config.filter),
    );
  }

  return {};
});
let splitFields = $derived.by(() => {
  if (dataset.type == "sql" || dataset.type == "percentage") {
    return [];
  }

  if (fields) {
    return Object.entries(fields)
        .flatMap(([field, config]) => config.split ? [field] : []);
  }

  return [];
});

const calculateActiveFields = (type: string) => {
  if (type === "percentage") {
    return ["numerator", "denominator"];
  }
  if (type === "sql") {
    return ["sql"];
  }

  return Object.entries(fields ?? {}).flatMap(([field, fieldConfig]) => {
    if (!fieldConfig.filter) {
      return [];
    }

    if (field in dataset) {
      return [field];
    }

    if (fieldConfig.type === "date" && (`${field}_from` in dataset || `${field}_to` in dataset)) {
      return [field];
    }

    return [];
  });
}

// untrack: this is manually updated by setType
let activeFields = $state(untrack(() => calculateActiveFields(dataset.type)));

const inactiveFields = $derived(Object.keys(filterFields).filter((field) => !activeFields.includes(field)));

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
    ...Object.entries(filterFields).flatMap(([field, fieldConfig]) => {
      if (fieldConfig.type === "date") {
        return [`${field}_from`, `${field}_to`];
      }

      return [field];
    }),
  ];

  for (const key of Object.keys(dataset)) {
    if (!allowedKeys.includes(key)) {
      delete dataset[key];
    }
  }

  if (dataset.type === "sql") {
    dataset.sql = SQL_DEFAULT;
  }

  activeFields = calculateActiveFields(newType);
}

const addFilter = (e: Event) => {
  activeFields.push(e.currentTarget.value);
  e.currentTarget.value = "";
}

const addSplit = (e: Event) => {
  if (dataset.split_by) {
    dataset.split_by.push(e.currentTarget.value);
  } else {
    dataset.split_by = [e.currentTarget.value];
  }

  e.currentTarget.value = "";
}

const removeSplit = (split: string) => {
  // We assume that dataset.split_by is an array and it contains split
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
  </label>

  <label>
    Type
    <select onchange="{setType}" value={dataset.type}>
      {#each types as type (type)}
        <option value={type}>{formatString(type)}</option>
      {/each}
    </select>
  </label>

  <Filter type="boolean" booleanDefault={true} model={dataset} key="visible">
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

  {#if splitFields.length > 0}
    <div class="border-l-2 border-ice-600 pl-4 mt-4 py-0.5 flex flex-col gap-3">
      <p class="text-sm font-medium text-ice-600">
        Splits
      </p>
      <p class="text-xs text-grey-600">
        Shows a separate chart series for each unique value of the given fields
      </p>
      {#if dataset.split_by}
        <div class="flex flex-wrap gap-2">
          {#each dataset.split_by as splitField}
            <div class="flex items-center gap-1">
              <div class="font-medium">
                {fields[splitField].label ?? formatString(splitField)}
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
            {#if !dataset.split_by?.includes(field)}
              <option value={field}>{filterFields[field]?.label ?? formatString(field)}</option>
            {/if}
          {/each}
        </select>
      </label>
    </div>
  {/if}

  <div class="border-l-2 border-ice-600 pl-4 mt-4 py-0.5 flex flex-col gap-3">
    <p class="text-sm font-medium text-ice-600">
      Filters
    </p>

    {#each Object.entries(filterFields) as [field, fieldConfig] (field)}
      {#if activeFields.includes(field)}
        {@const fieldLabel = fieldConfig.label ?? formatString(field)}

        {#if fieldConfig.type === "boolean"}
          <Filter
            type="switch"
            model={dataset}
            leftLabel={fieldConfig.leftLabel}
            leftValue={fieldConfig.leftValue}
            rightLabel={fieldConfig.rightLabel}
            rightValue={fieldConfig.rightValue}
            key={field}
          >
            {fieldLabel}
          </Filter>
        {:else if fieldConfig.type === "date"}
          <Filter
            type="date"
            model={dataset}
            key={`${field}_from`}
            description={fieldConfig.description}
          >
            {fieldLabel} from
          </Filter>

          <Filter
            type="date"
            model={dataset}
            key={`${field}_to`}
            description={fieldConfig.description}
          >
            {fieldLabel} to
          </Filter>
        {:else if fieldConfig.type === "sql"}
          <Filter
            type="textarea"
            model={dataset}
            key={field}
            class="font-mono text-red-800 bg-red-50/50 p-1 border border-red-800"
            rows="10"
            readonly={!canDangerouslyUseSql}
          >
            SQL Query

            {#snippet description()}
              <span class="help-text">
                Note: your query must return three columns: <code>date</code>, <code>split</code>, and <code>count</code>. <code>split</code> can be <code>NULL</code>
              </span>
            {/snippet}
          </Filter>
        {:else if fieldConfig.options}
          <Filter
            type="select"
            model={dataset}
            key={field}
            selectOptions={fieldConfig.options}
            description={fieldConfig.description}
          >
            {fieldLabel}
          </Filter>
        {:else}
          <Filter model={dataset} key={field} description={fieldConfig.description}>
            {fieldLabel}
          </Filter>
        {/if}
      {/if}
    {/each}

    {#if inactiveFields.length > 0}
      <label class="{activeFields.length > 0 ? "mt-4" : ""}">
        <span class="sr-only">Add a filter</span>
        <select
          onchange={addFilter}
          class="text-gray-600"
        >
          <option selected value="">Add a filter</option>
          {#each inactiveFields as field}
            <option value={field}>{filterFields[field].label ?? formatString(field)}</option>
          {/each}
        </select>
      </label>
    {/if}
  </div>

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

    {#if confirmDelete}
      <button type="button" class="sm bg-dawn-100 ml-auto" onclick={onDelete}>Yes, delete this dataset</button>
    {:else}
      <button type="button" class="sm bg-dawn-100 ml-auto" onclick={() => (confirmDelete = true)}>Delete</button>
    {/if}
  </div>
</ExpandingSection>
