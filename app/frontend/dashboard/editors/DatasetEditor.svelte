<script lang="ts">
  import type {
    ChartConfig,
    CommonDataset,
    Dataset,
    EventDataset,
    PercentageDataset, SqlDataset,
    ViewDataset,
    VisitDataset
  } from "../../types";
import Icon from "../components/Icon.svelte";
import Switch from "../components/Switch.svelte";
  import Filter from "../components/Filter.svelte";

const sqlDefault = (datasetId: string) => `SELECT
  '${datasetId}' as "id",
  NULL as "split",
  DATE(skadi_events.created_at) as "label",
  COUNT(*) as "count"
FROM skadi_events
GROUP BY DATE(skadi_events.created_at)`;

const { chartConfig, dataset, index, startOpen = false, onDelete, onDuplicate, onMoveUp, onMoveDown }: {
  chartConfig: ChartConfig,
  dataset: Dataset;
  index: number;
  startOpen?: boolean;
  onDelete: () => void;
  onDuplicate: () => void;
  onMoveUp?: null | (() => void);
  onMoveDown?: null | (() => void);
} = $props();

let derivedSources = $derived.by(() => {
  if (dataset.type !== "percentage") {
    return [];
  }

  return chartConfig.datasets
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
})

let open = $state(startOpen);
let confirmDelete: boolean = $state(false);

const toggleOpen = () => {
  open = !open;
}

const typeFields: {
  common: (keyof CommonDataset)[]
  visits: (keyof VisitDataset)[];
  views: (keyof ViewDataset)[];
  events: (keyof EventDataset)[];
  percentage: (keyof PercentageDataset)[];
  sql: (keyof SqlDataset)[];
} = {
  common: ["id", "label", "visible", "axis", "type"],
  visits: [],
  views: ["split_by", "view_controller", "view_action", "view_path", "view_verb", "view_version"],
  events: ["event_name"],
  percentage: ["numerator", "denominator"],
  sql: ["sql"],
}
const setType = (event: Event & {currentTarget: EventTarget & HTMLSelectElement}) => {
  const newType = event.currentTarget.value;

  dataset.type = newType as typeof dataset.type;

  const types = typeFields.common.concat(typeFields[newType]);
  for (const key of Object.keys(dataset)) {
    if (!types.includes(key)) {
      delete dataset[key];
    }
  }

  if (newType === "sql") {
    dataset.sql = sqlDefault(dataset.id);
  }
}

const duplicate = () => {
  onDuplicate();
  open = false;
}
</script>

<div class="border-l-4 border-night-700 pl-4 py-0.5">
  <button class="group w-full flex justify-between items-center unstyled cursor-pointer py-0.5" onclick={toggleOpen}>
    <p class="text-sm font-semibold text-night-700 group-hover:text-night-800">
      {#if open}
        Dataset {index + 1}
      {:else}
        <span class="capitalize">{dataset.type}</span> dataset: {dataset.label}
      {/if}
    </p>
    <Icon name={open ? "chevron_up" : "chevron_down"} size={24} class="text-ice-800 group-hover:text-black" />
  </button>

  <div class="contents">
    <div class="grid transition-[grid-template-rows] ease-in-out overflow-hidden {open ? "grid-rows-[1fr]" : "grid-rows-[0fr]"}">
      <div class="flex flex-col gap-3 pb-2 mt-2 overflow-hidden">
        <label>
          Label
          <input type="text" bind:value={dataset.label} />
        </label>

        <label>
          Type
          <select onchange="{setType}" value={dataset.type}>
            <option value="visits">Visits</option>
            <option value="views">Views</option>
            <option value="events">Events</option>
            <option value="percentage">Percentage</option>
            <option value="sql">SQL</option>
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

        {#if dataset.type === "views"}
          <Filter
            type="select"
            model={dataset}
            key="split_by"
            selectOptions={[
              "",
              {label: "Controller", value: "controller"},
              {label: "Controller and action", value: "controller_action"},
              {label: "Path", value: "path"},
              {label: "HTTP Verb", value: "verb"},
              {label: "Version", value: "version"},
            ]}
          >
            Split by
          </Filter>

          <Filter model={dataset} key="view_path">
            Path
          </Filter>

          <Filter model={dataset} key="view_controller">
            Controller
          </Filter>

          <Filter model={dataset} key="view_action">
            Action
          </Filter>

          <Filter model={dataset} key="view_version">
            Version
          </Filter>

          <Filter
            type="select"
            model={dataset}
            key="view_verb"
            selectOptions={["", "GET", "POST", "PUT", "PATCH", "DELETE"]}
            description="Typically, GET requests are page views, and POST, PUT, PATCH and DELETE are form submissions."
          >
            HTTP Verb
          </Filter>
        {/if}

        {#if dataset.type === "events"}
          {#if dataset.split_by !== "name"}
            <Filter model={dataset} key="event_name">
              Event name
            </Filter>
          {/if}

          {#if !dataset.event_name}
            <Filter type="switch" rightValue="name" model={dataset} key="split_by">
              Split by name
            </Filter>
          {/if}
        {/if}

        {#if dataset.type === "percentage"}
          <Filter
            type="select"
            model={dataset}
            key="numerator"
            selectOptions={derivedSources}
            description="The dataset you are using for your target, e.g. a specific page view or event."
          >
            Numerator
          </Filter>

          <Filter
            type="select"
            model={dataset}
            key="denominator"
            selectOptions={derivedSources}
            description="The dataset you are using for comparison, e.g. the number of visits."
          >
            Denominator
          </Filter>
        {/if}

        {#if dataset.type === "sql"}
          <Filter
            type="textarea"
            model={dataset}
            key="sql"
            class="font-mono text-red-800 bg-red-50/50 p-1 border border-red-800"
            rows="10"
          >
            SQL Query

            {#snippet description()}
              <span class="help-text">
                Note: to be compatible with the line chart, your query must return four columns: <code>'{dataset.id}' as id</code>; <code>NULL</code> or a string value as <code>split</code>, which will split it into multiple datasets; <code>label</code>; <code>count</code>
              </span>
            {/snippet}
          </Filter>
        {/if}

        <div class="flex flex-row gap-2 mt-4">
          <button type="button" class="sm" onclick={duplicate}>Duplicate</button>
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
      </div>
    </div>
  </div>
</div>
