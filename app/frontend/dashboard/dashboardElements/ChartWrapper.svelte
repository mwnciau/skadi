<script lang="ts">
  import { onMount } from "svelte";
  import type { ChartConfig } from "../../types.d.ts";
  import ChartEditor from "../editors/ChartEditor.svelte";
  import { processDerivedDatasets, processLabels } from "../helpers/processData";
  import BarChart from "./BarChart.svelte";
  import LineChart from "./LineChart.svelte";
  import Icon from "../components/Icon.svelte";

  let { chartConfig, startEditing, onDelete, onDuplicate, onMoveUp, onMoveDown, onSave }: {
  chartConfig: ChartConfig;
  startEditing: boolean;
  onDelete: () => void;
  onDuplicate: () => void;
  onMoveUp?: null | (() => void);
  onMoveDown?: null | (() => void);
  onSave: (newChartConfig: ChartConfig) => void;
} = $props();

let editing = $state(startEditing);
let confirmDelete: boolean = $state(false);
let localChartConfig = $state(chartConfig);

// Make this shallow state using $state.raw. We don't care how the charting library uses it, only that it's notified when the whole dataset is changed
let data : Record<string, {x: string, y: number}[]> = $state.raw({});

const fetchData = (newChartConfig: ChartConfig | null = null) => {
  localChartConfig = newChartConfig ?? chartConfig;

  const chartConfigJSON = encodeURIComponent(JSON.stringify(localChartConfig));
  return fetch(`/skadi/data/${chartConfig.id}?config=${chartConfigJSON}`)
    .then((response) => {
      if (!response.ok) {
        return response.json().then((body) => {
          throw new Error(body.error ?? `Request failed with status ${response.status}`);
        });
      }

      return response.json();
    })
    .then((items) => {
      const newData = {};

      for (const item of items) {
        const key = item.split ? `${item.id} ${item.split}` : item.id;
        newData[key] ??= [];
        newData[key].push({x: item.label, y: item.count});
      }

      processLabels(localChartConfig, newData)
      processDerivedDatasets(localChartConfig.datasets, newData);
      data = newData;
    });
}

const reloadChartData = (localChartConfig: ChartConfig | null = null) => {
  return fetchData(localChartConfig);
}

const saveChartConfig = (newChartConfig: ChartConfig) => {
  onSave(newChartConfig);
  localChartConfig = newChartConfig;

  editing = false;
}

onMount(() => {
  fetchData();
})
</script>

{#if localChartConfig.type === "line"}
  <LineChart chartConfig={localChartConfig} {data} />
{:else if localChartConfig.type === "bar"}
  <BarChart chartConfig={localChartConfig} {data} />
{/if}

{#if editing}
  <ChartEditor
    {chartConfig}
    reloadChartData={reloadChartData}
    onClose={() => (editing = false)}
    onSave={saveChartConfig}
  />
{:else}
  <div class="flex gap-2">
    <button onclick={() => (editing = true)}>Edit</button>
    <button onclick={onDuplicate}>Duplicate</button>
    {#if onMoveUp !== null }
      <button type="button" class="sm px-1" onclick={onMoveUp}><Icon name="chevron_up" size={24} /></button>
    {/if}
    {#if onMoveDown !== null }
      <button type="button" class="sm px-1" onclick={onMoveDown}><Icon name="chevron_down" size={24} /></button>
    {/if}

    {#if confirmDelete}
      <button type="button" class="bg-dawn-100 ml-auto" onclick={onDelete}>Yes, delete this chart</button>
    {:else}
      <button type="button" class="bg-dawn-100 ml-auto" onclick={() => (confirmDelete = true)}>Delete</button>
    {/if}
  </div>
{/if}
