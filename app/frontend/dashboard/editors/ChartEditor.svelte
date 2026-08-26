<script lang="ts">
import { untrack } from "svelte";
import type { ChartConfig, Dataset } from "../../types";
import Filter from "../components/Filter.svelte";
import Icon from "../components/Icon.svelte";
import DatasetEditor from "./DatasetEditor.svelte";

let { canDangerouslyUseSql, chartConfig, reloadChartData, onClose, onSave }: {
  canDangerouslyUseSql: boolean;
  chartConfig: ChartConfig;
  reloadChartData: (chartConfig: ChartConfig) => Promise<void>;
  onClose: () => void;
  onSave: (newChartConfig: ChartConfig) => void;
} = $props();

// untrack: this is just sets the default value whereupon this component controls the state
let localChartConfig = $state($state.snapshot(untrack(() => chartConfig)));

let chartConfigString = $derived(JSON.stringify(chartConfig));
let localChartConfigString = $derived(JSON.stringify(localChartConfig));

// untrack: this is manually updated when the preview changes
let displayedChartConfigString = $state(untrack(() => chartConfigString));

let unsavedChanges = $derived(chartConfigString !== localChartConfigString);
let unpreviewedChanges = $derived(localChartConfigString !== displayedChartConfigString);

let errorMessage: string | null = $state(null);
let datasetIdToOpen: string | null = $state(null);

const saveChanges = () => {
  onSave(localChartConfig);
}

const cancelChanges = () => {
  // If we've previewed at all, reset the chart display
  if (displayedChartConfigString !== chartConfigString) {
    // Revert to the original chart data
    reloadChartData(chartConfig);
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
      errorMessage = error.message.trim().replace(/Configuration configuration\[\d+\]\.children\[\d+\]\./g, "");
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

  if (newType === "table") {
    localChartConfig.type = "table";

    // Remove percentage datasets because they don't work with the table type
    localChartConfig.datasets = localChartConfig.datasets.filter((dataset) => dataset.type !== "percentage");

    // Ensure that at least one dataset still exists
    if (localChartConfig.datasets.length === 0) {
      addDataset();
    } else {
      // Delete all but the first dataset
      localChartConfig.datasets.splice(1);
    }

    // These fields are meaningless for the table type so we delete them
    ["visible", "axis", "split_by"].forEach((key) => {
      delete (localChartConfig.datasets[0] as Record<string, unknown>)[key];
    })

    delete localChartConfig.time_series;
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
  const newDataset = $state.snapshot(localChartConfig.datasets[index]) as Dataset;
  newDataset.id = crypto.randomUUID();
  datasetIdToOpen = newDataset.id;
  newDataset.label = `Copy of ${newDataset.label}`

  localChartConfig.datasets.splice(index + 1, 0, newDataset);
}

const moveUp = (index: number) => {
  if (index === 0) {
    return;
  }

  const thisDataset = localChartConfig.datasets[index];

  localChartConfig.datasets[index] = localChartConfig.datasets[index - 1] as Dataset;
  localChartConfig.datasets[index - 1] = thisDataset as Dataset;
}

const moveDown = (index: number) => {
  if (index >= localChartConfig.datasets.length - 1) {
    return;
  }

  const thisDataset = localChartConfig.datasets[index];

  localChartConfig.datasets[index] = localChartConfig.datasets[index + 1] as Dataset;
  localChartConfig.datasets[index + 1] = thisDataset as Dataset;
}
</script>

<div class="shrink-0 flex flex-col gap-4 border-l-4 border-ice-400 pl-4">
  <p class="font-semibold text-ice-700">Editing chart</p>

  <label>
    Title
    <input type="text" bind:value={localChartConfig.title} />
  </label>

  <Filter
    type="contenteditable"
    model={localChartConfig}
    key="description"
    placeholder="Enter a description for this chart"
  >
    Description
  </Filter>

  <div class="sm:grid grid-cols-2 gap-x-2 gap-y-4 items-start">
    <label class="only:col-span-2">
      Type
      <select onchange={setType} value={localChartConfig.type}>
        <option value="line">Line chart</option>
        <option value="bar">Bar chart</option>
        <option value="table">Table</option>
      </select>
    </label>

    {#if localChartConfig.type !== "table"}
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
    {/if}
  </div>

  <div class="flex flex-wrap gap-2 items-center">
    <div class="flex gap-2 items-center sm:contents">
      Include data from
      <Filter type="date" model={localChartConfig} key="date_from">
        <span class="sr-only">Date from</span>
      </Filter>
    </div>
    <div class="flex gap-2 items-center sm:contents">
      to
      <Filter type="date" model={localChartConfig} key="date_to">
        <span class="sr-only">Date to</span>
      </Filter>
    </div>
  </div>

  <div class="flex flex-col gap-4 mt-1 max-w-160">
    {#each localChartConfig.datasets as dataset, index (dataset.id)}
      <DatasetEditor
        {canDangerouslyUseSql}
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

    {#if localChartConfig.type !== "table"}
      <button type="button" class="sm text-sm ghost w-full border-l-4 border-night-100 hover:border-night-700 pl-4 hover:bg-transparent hover:backdrop-filter-none" onclick={addDataset}>
        <Icon name="plus" size={18} class="-ml-1 mt-px" />
        New dataset
      </button>
    {/if}
  </div>

  {#if errorMessage}
    <div class="p-1 px-2 bg-red-50/50 border border-red-500">
      <p class="text-red-800 font-semibold">Unable to preview the chart:</p>
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
