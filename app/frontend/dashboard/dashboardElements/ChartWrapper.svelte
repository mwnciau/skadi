<script lang="ts">
  import { onMount } from "svelte";
  import type { ChartConfig, ChartData, DashboardConfig, ResponseData } from "../../types.d.ts";
  import ChartEditor from "../editors/ChartEditor.svelte";
  import { fillDataGaps, processDerivedDatasets, formatDates, createChartData } from "../helpers/processData";
  import BarChart from "./BarChart.svelte";
  import StaticDataTable from "./StaticDataTable.svelte";
  import LineChart from "./LineChart.svelte";
  import Icon from "../components/Icon.svelte";

  let { dashboardConfig, chartConfig, startEditing, onDelete, onDuplicate, onMoveUp, onMoveDown, onSave }: {
  dashboardConfig: DashboardConfig,
  chartConfig: ChartConfig;
  startEditing: boolean;
  onDelete: () => void;
  onDuplicate: () => void;
  onMoveUp?: null | (() => void);
  onMoveDown?: null | (() => void);
  onSave: (newChartConfig: ChartConfig) => void;
} = $props();

let editing = $state(startEditing);
let viewData = $state(false);
let confirmDelete: boolean = $state(false);
let localChartConfig = $state(chartConfig);

// Make this shallow state using $state.raw. We don't care how the charting library uses it, only that it's notified when the whole dataset is changed
let data : ChartData = $state.raw([]);

const fetchData = (newChartConfig: ChartConfig | null = null) => {
  localChartConfig = newChartConfig ?? chartConfig;

  let additionalQueryVars = "";
  if (dashboardConfig.date_from) {
    additionalQueryVars += `&date_from=${dashboardConfig.date_from}`
  }
  if (dashboardConfig.date_to) {
    additionalQueryVars += `&date_to=${dashboardConfig.date_to}`
  }

  const chartConfigJSON = encodeURIComponent(JSON.stringify(localChartConfig));
  return fetch(`/skadi/data/${chartConfig.id}?config=${chartConfigJSON}${additionalQueryVars}`)
    .then((response) => {
      if (!response.ok) {
        return response.json().then((body) => {
          throw new Error(body.error ?? `Request failed with status ${response.status}`);
        });
      }

      return response.json();
    })
    .then((items) => {
      const responseData: ResponseData = {};

      for (const item of items) {
        const key: string = item.split ? `${item.id} ${item.split}` : item.id;
        responseData[key] ??= [];
        responseData[key].push({x: item.label, y: item.count});
      }

      processDerivedDatasets(localChartConfig, responseData);
      fillDataGaps(localChartConfig, responseData);
      formatDates(localChartConfig, responseData)
      data = createChartData(localChartConfig, responseData);
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

{#if viewData}
  <StaticDataTable chartConfig={localChartConfig} {data} />
{:else}
  {#if localChartConfig.type === "line"}
    <LineChart chartConfig={localChartConfig} {data} />
  {:else if localChartConfig.type === "bar"}
    <BarChart chartConfig={localChartConfig} {data} />
  {/if}
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
      <button type="button" class="bg-dawn-100" onclick={onDelete}>Yes, delete this chart</button>
      <button type="button" class="ghost text-gray-600" onclick={() => (confirmDelete = false)}>Cancel</button>
    {:else}
      <button type="button" class="bg-dawn-100" onclick={() => (confirmDelete = true)}>Delete</button>
    {/if}

    <div class="ml-auto"></div>

    <button type="button" onclick={() => (viewData = !viewData)}>{viewData ? "Show Graph" : "Show Data"}</button>
  </div>
{/if}
