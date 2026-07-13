<script lang="ts">
import type {ChartConfig} from "../../types";
import DatasetEditor from "./DatasetEditor.svelte";
import Icon from "../components/Icon.svelte";

const { chartConfig, reloadChart }: {
  chartConfig: ChartConfig;
  reloadChart: () => void;
} = $props();

let persistedChartConfigString = $state(JSON.stringify(chartConfig));
let unsavedChanges = $derived.by(() => JSON.stringify(chartConfig) !== persistedChartConfigString);

// Intentionally left state-less because this will be a one-off thing when the dataset is duplicated
let duplicatedDatasetId: string | null = null;

const addDataset = () => {
  chartConfig.datasets.push({
    id: crypto.randomUUID(),
    label: `Dataset ${chartConfig.datasets.length + 1}`,
    type: "views",
  });
}

const deleteDataset = (index: number) => () => {
  chartConfig.datasets.splice(index, 1);
}
const duplicateDataset = (index: number) => {
  const newDataset = $state.snapshot(chartConfig.datasets[index]);
  newDataset.id = crypto.randomUUID();
  duplicatedDatasetId = newDataset.id;
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

  <div class="flex flex-col gap-4 max-w-124">
    {#each chartConfig.datasets as dataset, index (dataset.id)}
      <DatasetEditor
        {dataset}
        {index}
        startOpen={dataset.id === duplicatedDatasetId}
        onDelete={() => deleteDataset(index)}
        onDuplicate={() => duplicateDataset(index)}
        onMoveUp={index !== 0 ? (() => moveUp(index)) : null}
        onMoveDown={index !== chartConfig.datasets.length - 1 ? (() => moveDown(index)) : null}
      />
    {/each}

    <button type="button" class="sm text-sm ghost w-full border-l-4 border-night-700 pl-4 hover:bg-transparent hover:backdrop-filter-none" onclick={addDataset}>
      <Icon name="plus" size={18} />
      New dataset
    </button>
  </div>

  {#if unsavedChanges}
    <button type="button" class="emph mt-4" onclick={reloadChart}>Preview changes</button>
  {/if}
</div>
