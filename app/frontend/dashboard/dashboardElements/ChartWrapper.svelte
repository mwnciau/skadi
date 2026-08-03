<script lang="ts">
  import { untrack } from "svelte";
  import type { ChartConfig, ChartData, DashboardTabConfig, ResponseData, TabFilters } from "../../types.d.ts";
  import ChartEditor from "../editors/ChartEditor.svelte";
  import { fillDataGaps, processDerivedDatasets, formatDates, createChartData } from "../helpers/processData";
  import BarChart from "./BarChart.svelte";
  import StaticDataTable from "./StaticDataTable.svelte";
  import LineChart from "./LineChart.svelte";
  import Icon from "../components/Icon.svelte";
  import { fetchChartData } from "../helpers/requestHandler";

  let { canDangerouslyUseSql, chartConfig, editingEnabled, startEditing, tabFilters, onDelete, onDuplicate, onMoveUp, onMoveDown, onSave }: {
  canDangerouslyUseSql: boolean;
  chartConfig: ChartConfig;
  editingEnabled: boolean;
  tabFilters: TabFilters;
  startEditing: boolean;
  onDelete: () => void;
  onDuplicate: () => void;
  onMoveUp?: null | (() => void);
  onMoveDown?: null | (() => void);
  onSave: (newChartConfig: ChartConfig) => void;
} = $props();

// untrack: this is a one-time default that lets the parent control the default state
let isEditingChart = $state(untrack(() => startEditing));
let viewData = $state(false);
let confirmDelete: boolean = $state(false);

// untrack: this is manually updated by fetchData
let localChartConfig = $state(untrack(() => chartConfig));

// Make this shallow state using $state.raw. We don't care how the charting library uses it, only that it's notified when the whole dataset is changed
let data : ChartData = $state.raw([]);

const fetchData = (newChartConfig: ChartConfig | null = null) => {
  localChartConfig = newChartConfig ?? chartConfig;

  return fetchChartData(chartConfig.id, tabFilters, newChartConfig)
    .then((items) => {
      const responseData: ResponseData = {};

      for (const item of items) {
        const key: string = item.split ? `${item.id} ${item.split}` : item.id;
        responseData[key] ??= [];
        responseData[key].push({x: item.date, y: item.count});
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

  isEditingChart = false;
}

$effect(() => {
  // Ensure this effect is run when tabFilters changes
  JSON.stringify(tabFilters);

  untrack(() => {
    fetchData();
  });
});
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

{#if isEditingChart}
  <ChartEditor
    {canDangerouslyUseSql}
    {chartConfig}
    reloadChartData={reloadChartData}
    onClose={() => (isEditingChart = false)}
    onSave={saveChartConfig}
  />
{:else}
  <div class="flex gap-2">
    {#if editingEnabled}
      <button onclick={() => (isEditingChart = true)}>Edit</button>
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
    {/if}

    <div class="ml-auto"></div>

    <button type="button" onclick={() => (viewData = !viewData)}>{viewData ? "Show Graph" : "Show Data"}</button>
  </div>
{/if}
