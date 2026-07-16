<script lang="ts">
import type {ChartConfig} from "../../types";
import DatasetEditor from "./DatasetEditor.svelte";
import Icon from "../components/Icon.svelte";
import Switch from "../components/Switch.svelte";

let { chartConfig = $bindable(), reloadChart, onCancel }: {
  chartConfig: ChartConfig;
  reloadChart: () => Promise<any>;
  onCancel: () => void;
} = $props();

let chartConfigString = $derived(JSON.stringify(chartConfig));
let persistedChartConfigString = $state(chartConfigString);
let previewChartConfigString = $state(chartConfigString);
let unsavedChanges = $derived.by(() => chartConfigString !== persistedChartConfigString);
let unpreviewedChanges = $derived.by(() => chartConfigString !== previewChartConfigString);
let previewLoaded = $derived(previewChartConfigString === chartConfigString)

let errorMessage: string | null = $state(null);

// Intentionally left state-less because this will be a one-off thing when a dataset is added or duplicated
let datasetIdToOpen: string | null = null;

const saveChanges = () => {
  persistedChartConfigString = chartConfigString;
  previewChartConfigString = persistedChartConfigString;

  // Todo: save changes
}

const cancelChanges = () => {
  chartConfig = JSON.parse(persistedChartConfigString);
  previewChartConfigString = persistedChartConfigString;
  reloadChart();
  onCancel();
}

const previewChanges = () => {
  const requestedPreviewString = chartConfigString;
  reloadChart()
    .then(() => {
      previewChartConfigString = requestedPreviewString;
      errorMessage = null;
    })
    .catch(error => {
      errorMessage = error.message.trim();
    });
}

const addDataset = () => {
  const datasetId = crypto.randomUUID();
  datasetIdToOpen = datasetId;
  chartConfig.datasets.push({
    id: datasetId,
    label: `Dataset ${chartConfig.datasets.length + 1}`,
    type: "visits",
  });
}

const deleteDataset = (index: number) => () => {
  chartConfig.datasets.splice(index, 1);
}
const duplicateDataset = (index: number) => {
  const newDataset = $state.snapshot(chartConfig.datasets[index]);
  newDataset.id = crypto.randomUUID();
  datasetIdToOpen = newDataset.id;
  newDataset.label = `Copy of ${newDataset.label}`

  chartConfig.datasets.splice(index + 1, 0, newDataset);
}

const moveUp = (index: number) => {
  if (index === 0) {
    return;
  }

  // Splice returns the items that were removed, so this overwrites `index - 1` with `index`, then sets `index` to the removed item
  chartConfig.datasets[index] = chartConfig.datasets.splice(index - 1, 1, chartConfig.datasets[index])[0];
}

const moveDown = (index: number) => {
  if (index >= chartConfig.datasets.length - 1) {
    return;
  }

  // Splice returns the items that were removed, so this overwrites `index` with `index + 1`, then sets `index + 1` to the removed item
  chartConfig.datasets[index + 1] = chartConfig.datasets.splice(index, 1, chartConfig.datasets[index + 1])[0];
}

const toggleFilterBoolean = (key: string, defaultValue = false) => {
  if (chartConfig[key] === !defaultValue) {
    delete chartConfig[key];
  } else {
    chartConfig[key] = !defaultValue;
  }
}

const setVisitTracking = (newValue: string) => {
  if (!newValue) {
    delete chartConfig.visit_tracking;
  } else {
    chartConfig.visit_tracking = newValue as typeof chartConfig.visit_tracking;
  }
}
</script>

<div class="flex flex-col gap-4 border-l-4 border-ice-400 pl-4">
  <p class="text-sm font-semibold text-ice-700">Chart config</p>

  <label>
    Title
    <input type="text" bind:value={chartConfig.title} />
  </label>

  <label>
    Type
    <select bind:value={chartConfig.type}>
      <option value="line">Line chart</option>
    </select>
  </label>

  <label>
    X axis
    <select bind:value={chartConfig.group}>
      <option value="day">Day</option>
      <option value="week">Week</option>
      <option value="month">Month</option>
    </select>
  </label>

  <label>
    Show only verified visits and views
    <Switch value={chartConfig?.verified === true} onToggle={() => toggleFilterBoolean("verified")} />
    <span class="help-text">
      Visits and views are created by the backend, and verified by a frontend request. Enabling this will filter out some bots and prevent page pre-fetching being tracked.
    </span>
  </label>

  <label>
    Deduplicate views and events per visit
    <Switch value={chartConfig?.unique_visits === true} onToggle={() => toggleFilterBoolean("unique_visits")} />
  </label>

  <label>
    Visit tracking
    <select onchange="{event => setVisitTracking(event.target.value)}" value={chartConfig?.visit_tracking}>
      <option value="">Show all visits</option>
      <option value="any">Show visits tracked by anonymity set or cookie</option>
      <option value="anonymity_set">Show visits tracked by anonymity set</option>
      <option value="cookie">Show visits tracked by cookie</option>
    </select>
  </label>

  <div class="flex flex-col gap-4 max-w-160 mt-4">
    {#each chartConfig.datasets as dataset, index (dataset.id)}
      <DatasetEditor
        {chartConfig}
        {dataset}
        {index}
        startOpen={dataset.id === datasetIdToOpen}
        onDelete={() => deleteDataset(index)}
        onDuplicate={() => duplicateDataset(index)}
        onMoveUp={index !== 0 ? (() => moveUp(index)) : null}
        onMoveDown={index !== chartConfig.datasets.length - 1 ? (() => moveDown(index)) : null}
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
    {/if}

    {#if unsavedChanges && previewLoaded}
      <button type="button" class="emph" onclick={saveChanges}>Save</button>
    {/if}

    <button type="button" class="bg-gray-100" onclick={cancelChanges}>Cancel</button>
  </div>
</div>
