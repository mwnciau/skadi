<script lang="ts">
import type {ChartConfig} from "../../types";
import DatasetEditor from "./DatasetEditor.svelte";
import Icon from "../components/Icon.svelte";
import Filter from "../components/Filter.svelte";

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
      console.error(error);
    });
}

const setType = (event: Event & {currentTarget: EventTarget & HTMLSelectElement}) => {
  const newType = event.currentTarget.value;

  if (newType === "line") {
    localChartConfig.type = "line";
    localChartConfig.time_series ??= "daily"
  }

  if (newType === "bar") {
    localChartConfig.type = "bar";

    if (localChartConfig.time_series === "daily") {
      delete localChartConfig.time_series;
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
</script>

<div class="flex flex-col gap-4 border-l-4 border-ice-400 pl-4">
  <p class="text-sm font-semibold text-ice-700">Chart config</p>

  <label>
    Title
    <input type="text" bind:value={localChartConfig.title} />
  </label>

  <label>
    Type
    <select onchange={setType} value={localChartConfig.type}>
      <option value="line">Line chart</option>
      <option value="bar">Bar chart</option>
    </select>
  </label>

  <Filter type="select" model={localChartConfig} key="time_series">
    Time series

    {#snippet selectOptions()}
      {#if localChartConfig.type !== "line"}
        <option value="">All time</option>
      {/if}
      {#if localChartConfig.type !== "bar"}
        <option value="daily">Daily</option>
      {/if}
      <option value="weekly">Weekly</option>
      <option value="monthly">Monthly</option>
    {/snippet}
  </Filter>


  <Filter
    type="boolean"
    model={localChartConfig}
    key="verified"
    description="Visits and views are created by the backend, and verified by a frontend request. Enabling this will filter out some bots and prevent page pre-fetching being tracked."
  >
    Show only verified visits and views
  </Filter>

  <Filter
    type="boolean"
    model={localChartConfig}
    key="unique_visits"
  >
    Deduplicate views and events per visit
  </Filter>

  <Filter
    type="select"
    model={localChartConfig}
    key="visit_tracking"
    selectOptions={[
      {label: "Show all visits", value: ""},
      {label: "Show visits tracked by anonymity set or cookie", value: "any"},
      {label: "Show visits tracked by anonymity set", value: "anonymity_set"},
      {label: "Show visits tracked by cookie", value: "cookie"},
    ]}
  >
    Visit tracking
  </Filter>

  <Filter
    type="date"
    model={localChartConfig}
    key="date_from"
    description="This is combined with the dashboard's date from, and the later (more restrictive) of the two dates is used."
  >
    Date from
  </Filter>

  <Filter
    type="date"
    model={localChartConfig}
    key="date_to"
    description="This is combined with the dashboard's date to, and the earlier (more restrictive) of the two dates is used."
  >
    Date to
  </Filter>

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
