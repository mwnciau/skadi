<script lang="ts">
import type {ChartConfig} from "../../types";
import DatasetEditor from "./DatasetEditor.svelte";

const { chartConfig }: {
  chartConfig: ChartConfig;
} = $props();

let persistedChartConfigString = $state(JSON.stringify(chartConfig));
let unsavedChanges = $derived.by(() => JSON.stringify(chartConfig) !== persistedChartConfigString);

const addDataset = () => {
  chartConfig.datasets.push({
    id: crypto.randomUUID(),
    label: `Dataset ${chartConfig.datasets.length + 1}`,
    type: "views",
    filters: {},
  });
}

const deleteDataset = (index: number) => () => {
  chartConfig.datasets.splice(index, 1);
}
</script>

<div class="flex flex-col gap-2">
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

  {#each chartConfig.datasets as dataset, index (dataset.id)}
    <DatasetEditor {dataset} {index} onDelete={deleteDataset(index)} />
  {/each}

  <div class="flex justify-center max-w-124">
    <button type="button" class="sm ghost" onclick={addDataset}>Add dataset</button>
  </div>

  {#if unsavedChanges}
    <button type="button" class="emph mt-4">Save changes</button>
  {/if}


  <pre>{JSON.stringify(chartConfig, null, 2)}</pre>
</div>
