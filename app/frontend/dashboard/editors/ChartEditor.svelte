<script lang="ts">
import type {ChartConfig} from "../../types";
import DatasetEditor from "./DatasetEditor.svelte";
import Icon from "../components/Icon.svelte";
import Switch from "../components/Switch.svelte";

let { chartConfig, reloadChartData, onClose, onSave }: {
  chartConfig: ChartConfig;
  reloadChartData: (chartConfig?: ChartConfig) => Promise<any>;
  onClose: () => void;
  onSave: (newChartConfig: ChartConfig) => void;
} = $props();

let localChartConfig = $state($state.snapshot(chartConfig));

let chartConfigString = $derived(JSON.stringify(chartConfig));
let localChartConfigString = $derived(JSON.stringify(localChartConfig));

let displayedChartConfigString = $state(chartConfigString);

let unsavedChanges = $derived(chartConfigString !== localChartConfigString);
let unpreviewedChanges = $derived(localChartConfigString !== displayedChartConfigString);

let errorMessage: string | null = $state(null);

// Intentionally left state-less because this will be a one-off thing when a dataset is added or duplicated
let datasetIdToOpen: string | null = null;

const saveChanges = () => {
  onSave(localChartConfig);
}

const cancelChanges = () => {
  // If we've previewed at all, reset the chart display
  if (displayedChartConfigString !== chartConfigString) {
    reloadChartData();
  }

  onClose();
}

const previewChanges = () => {
  const requestedPreviewString = localChartConfigString;
  reloadChartData($state.snapshot(localChartConfig))
    .then(() => {
      displayedChartConfigString = requestedPreviewString;
      errorMessage = null;
    })
    .catch(error => {
      errorMessage = error.message.trim();
    });
}

const setType = (newType: typeof localChartConfig.type) => {
  if (newType === "line") {
    localChartConfig.type = "line";
    localChartConfig.group ??= "day"
  }

  if (newType === "bar") {
    localChartConfig.type = "bar";

    if (localChartConfig.group === "day") {
      delete localChartConfig.group;
    }
  }
}

const addDataset = () => {
  const datasetId = crypto.randomUUID();
  datasetIdToOpen = datasetId;
  localChartConfig.datasets.push({
    id: datasetId,
    label: `Dataset ${localChartConfig.datasets.length + 1}`,
    type: "visits",
  });
}

const deleteDataset = (index: number) => {
  localChartConfig.datasets.splice(index, 1);
}

const duplicateDataset = (index: number) => {
  const newDataset = $state.snapshot(localChartConfig.datasets[index]);
  newDataset.id = crypto.randomUUID();
  datasetIdToOpen = newDataset.id;
  newDataset.label = `Copy of ${newDataset.label}`

  localChartConfig.datasets.splice(index + 1, 0, newDataset);
}

const moveUp = (index: number) => {
  if (index === 0) {
    return;
  }

  // Splice returns the items that were removed, so this overwrites `index - 1` with `index`, then sets `index` to the removed item
  localChartConfig.datasets[index] = localChartConfig.datasets.splice(index - 1, 1, localChartConfig.datasets[index])[0];
}

const moveDown = (index: number) => {
  if (index >= localChartConfig.datasets.length - 1) {
    return;
  }

  // Splice returns the items that were removed, so this overwrites `index` with `index + 1`, then sets `index + 1` to the removed item
  localChartConfig.datasets[index + 1] = localChartConfig.datasets.splice(index, 1, localChartConfig.datasets[index + 1])[0];
}

const toggleFilterBoolean = (key: string, defaultValue = false) => {
  if (localChartConfig[key] === !defaultValue) {
    delete localChartConfig[key];
  } else {
    localChartConfig[key] = !defaultValue;
  }
}

const setFilterString = (filter: string, value: string) => {
  if (value) {
    localChartConfig[filter] = value;
  } else {
    delete localChartConfig[filter];
  }
}
</script>

<div class="flex flex-col gap-4 border-l-4 border-ice-400 pl-4">
  <p class="text-sm font-semibold text-ice-700">Chart config</p>

  <label>
    Title
    <input type="text" bind:value={localChartConfig.title} />
  </label>

  <label>
    Type
    <select onchange={e => setType(e.target.value)} value={localChartConfig.type}>
      <option value="line">Line chart</option>
      <option value="bar">Bar chart</option>
    </select>
  </label>

  <label>
    Time series
    <select onchange={(e) => setFilterString("group", e.target.value)} value={localChartConfig.group ?? ""}>
      {#if localChartConfig.type !== "line"}
        <option value="">All time</option>
      {/if}
      {#if localChartConfig.type !== "bar"}
        <option value="day">Daily</option>
      {/if}
      <option value="week">Weekly</option>
      <option value="month">Monthly</option>
    </select>
  </label>

  <label>
    Show only verified visits and views
    <Switch value={localChartConfig?.verified === true} onToggle={() => toggleFilterBoolean("verified")} />
    <span class="help-text">
      Visits and views are created by the backend, and verified by a frontend request. Enabling this will filter out some bots and prevent page pre-fetching being tracked.
    </span>
  </label>

  <label>
    Deduplicate views and events per visit
    <Switch value={localChartConfig?.unique_visits === true} onToggle={() => toggleFilterBoolean("unique_visits")} />
  </label>

  <label>
    Visit tracking
    <select onchange="{event => setFilterString("visit_tracking", event.target.value)}" value={localChartConfig?.visit_tracking ?? ""}>
      <option value="">Show all visits</option>
      <option value="any">Show visits tracked by anonymity set or cookie</option>
      <option value="anonymity_set">Show visits tracked by anonymity set</option>
      <option value="cookie">Show visits tracked by cookie</option>
    </select>
  </label>

  <div class="flex flex-col gap-4 max-w-160 mt-4">
    {#each localChartConfig.datasets as dataset, index (dataset.id)}
      <DatasetEditor
        chartConfig={localChartConfig}
        {dataset}
        {index}
        startOpen={dataset.id === datasetIdToOpen}
        onDelete={() => deleteDataset(index)}
        onDuplicate={() => duplicateDataset(index)}
        onMoveUp={index !== 0 ? (() => moveUp(index)) : null}
        onMoveDown={index !== localChartConfig.datasets.length - 1 ? (() => moveDown(index)) : null}
      />
    {/each}

    <button type="button" class="sm text-sm ghost w-full border-l-4 border-night-100 hover:border-night-700 pl-4 hover:bg-transparent hover:backdrop-filter-none" onclick={addDataset}>
      <Icon name="plus" size={18} class="-ml-1 mt-px" />
      New dataset
    </button>
  </div>

  {#if errorMessage}
    <div class="p-1 px-2 bg-red-50/50 border border-red-500">
      <p class="text-red-800 font-semibold">An error occurred during this request:</p>
      <pre class="text-red-800 whitespace-pre-wrap">{errorMessage}</pre>
    </div>
  {/if}

  <div class="flex gap-2 mt-4">
    {#if unpreviewedChanges}
      <button type="button" class="emph bg-ice-600 text-white" onclick={previewChanges}>Preview</button>
    {:else}
      {#if unsavedChanges}
        <button type="button" class="emph" onclick={saveChanges}>Save</button>
      {/if}
    {/if}

    <button type="button" class="bg-gray-100" onclick={cancelChanges}>Cancel</button>
  </div>
</div>
