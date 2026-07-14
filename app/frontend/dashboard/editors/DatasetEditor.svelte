<script lang="ts">
  import type {
    ChartConfig,
    CommonDataset,
    Dataset,
    EventDataset,
    PercentageDataset,
    ViewDataset,
    VisitDataset
  } from "../../types";
import Icon from "../components/Icon.svelte";
import Switch from "../components/Switch.svelte";

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
const toggleOpen = () => {
  open = !open;
}

const typeFields: {
  common: (keyof CommonDataset)[]
  visits: (keyof VisitDataset)[];
  views: (keyof ViewDataset)[];
  events: (keyof EventDataset)[];
  percentage: (keyof PercentageDataset)[];
} = {
  common: ["id", "label", "visible", "axis", "type"],
  visits: [],
  views: ["split_by", "view_controller", "view_action", "view_path", "view_verb", "view_version"],
  events: ["event_name"],
  percentage: ["numerator", "denominator"],
}
const changeType = (newType: string) => {
  dataset.type = newType as typeof dataset.type;

  const types = typeFields.common + typeFields[newType];
  for (const key of Object.keys(dataset)) {
    if (!types.includes(key)) {
      delete dataset[key];
    }
  }
}

const toggleFilterBoolean = (key: string, defaultValue = false) => {
  if (dataset[key] === !defaultValue) {
    delete dataset[key];
  } else {
    dataset[key] = !defaultValue;
  }
}

const setFilterString = (filter: string, value: string) => {
  if (value) {
    dataset[filter] = value;
  } else {
    delete dataset[filter];
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
      Dataset {index + 1}
      {#if !open}
        - {dataset.label}
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
          <select onchange="{event => changeType(event.target.value)}" value={dataset.type}>
            <option value="visits">Visits</option>
            <option value="views">Views</option>
            <option value="events">Events</option>
            <option value="percentage">Percentage</option>
          </select>
        </label>

        <label>
          Show on chart
          <Switch value={dataset.visible !== false} onToggle={() => toggleFilterBoolean("visible", true)} />
        </label>

        {#if dataset.visible !== false}
          <label>
            Axis
            <div class="flex items-center gap-2 font-normal">
              Left
              <Switch
                value={dataset.axis === "right"}
                onToggle={() => setFilterString("axis", dataset.axis === "right" ? "" : "right")}
                labelOn=""
                labelOff=""
              />
              Right
            </div>
          </label>
        {/if}

        {#if dataset.type === "views"}
          <label>
            Split by
            <select onchange="{event => setFilterString("split_by", event.target.value)}" value={dataset?.split_by}>
              <option></option>
              <option value="controller">Controller</option>
              <option value="controller_action">Controller and action</option>
              <option value="path">Path</option>
              <option value="verb">Verb</option>
              <option value="version">Version</option>
            </select>
          </label>

          <label>
            Path
            <input type="text" onkeyup={event => setFilterString("view_path", event.target.value)} value={dataset?.view_path} />
          </label>

          <label>
            Controller
            <input type="text" onkeyup={event => setFilterString("view_controller", event.target.value)} value={dataset?.view_controller} />
          </label>

          <label>
            Action
            <input type="text" onkeyup={event => setFilterString("view_action", event.target.value)} value={dataset?.view_action} />
          </label>

          <label>
            Version
            <input type="text" onkeyup={event => setFilterString("view_version", event.target.value)} value={dataset?.view_version} />
          </label>

          <label>
            Verb
            <select onchange="{event => setFilterString("view_verb", event.target.value)}" value={dataset?.view_verb}>
              <option></option>
              <option>GET</option>
              <option>POST</option>
              <option>PUT</option>
              <option>PATCH</option>
              <option>DELETE</option>
            </select>
          </label>
        {/if}

        {#if dataset.type === "events"}
          {#if dataset.split_by !== "name"}
            <label>
              Event name
              <input type="text" onkeyup={event => setFilterString("event_name", event.target.value)} value={dataset?.event_name} />
            </label>
          {/if}

          {#if !dataset.event_name}
            <label>
              Split by name
              <Switch value={dataset.split_by === "name"} onToggle={() => setFilterString("split_by", dataset.split_by ? "" : "name")} />
            </label>
          {/if}
        {/if}

        {#if dataset.type === "percentage"}
          <label>
            Numerator
            <select onchange="{event => setFilterString("numerator", event.target.value)}" value={dataset?.numerator}>
              {#each derivedSources as source}
                <option value={source.value}>{source.label}</option>
              {/each}
            </select>
            <span class="help-text">
              The dataset you are using for your target, e.g. a specific page view or event.
            </span>
          </label>

          <label>
            Denominator
            <select onchange="{event => setFilterString("denominator", event.target.value)}" value={dataset?.denominator}>
              {#each derivedSources as source}
                <option value={source.value}>{source.label}</option>
              {/each}
            </select>
            <span class="help-text">
              The dataset you are using for comparison, e.g. the number of visits.
            </span>
          </label>
        {/if}

        <div class="flex flex-row gap-2 mt-4">
          <button type="button" class="sm bg-dawn-100" onclick={onDelete}>Delete</button>
          <button type="button" class="sm" onclick={duplicate}>Duplicate</button>
          {#if onMoveUp !== null }
            <button type="button" class="sm px-1" onclick={onMoveUp}><Icon name="chevron_up" size={24} /></button>
          {/if}
          {#if onMoveDown !== null }
            <button type="button" class="sm px-1" onclick={onMoveDown}><Icon name="chevron_down" size={24} /></button>
          {/if}
        </div>
      </div>
    </div>
  </div>
</div>
