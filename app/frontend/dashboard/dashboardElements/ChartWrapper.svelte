<script lang="ts">
  import { untrack } from "svelte";
  import type { ChartConfig, ChartData, ResponseData, TabFilters } from "../../types.d.ts";
  import Icon from "../components/Icon.svelte";
  import ChartEditor from "../editors/ChartEditor.svelte";
  import { createChartData, fillDataGaps, formatDates, processDerivedDatasets } from "../helpers/processData";
  import { fetchChartData } from "../helpers/requestHandler";
  import BarChart from "./BarChart.svelte";
  import LineChart from "./LineChart.svelte";
  import StaticDataTable from "./StaticDataTable.svelte";

  let { canDangerouslyUseSql, chartConfig, editingEnabled, newChartId = $bindable(), tabFilters, onDelete, onDuplicate, onMoveUp, onMoveDown, onSave }: {
  canDangerouslyUseSql: boolean;
  chartConfig: ChartConfig;
  editingEnabled: boolean;
  tabFilters: TabFilters;
  // The ID of the chart if it was recently added and should start open
  newChartId: string | null;
  onDelete: () => void;
  onDuplicate: () => void;
  onMoveUp?: null | (() => void);
  onMoveDown?: null | (() => void);
  onSave: (newChartConfig: ChartConfig) => void;
} = $props();

// untrack: this is a one-time default that lets the parent control the state
let isEditingChart = $state(untrack(() => chartConfig.id === newChartId));
let viewData = $state(false);
let confirmDelete: boolean = $state(false);

let loadError = $state(false);

// untrack: this is manually updated by fetchData
let localChartConfig = $state(untrack(() => chartConfig));
let dirtyChartConfig = $state(false);

// Make this shallow state using $state.raw. We don't care how the charting library uses it, only that it's notified when the whole dataset is changed
let data : ChartData = $state.raw([]);

const fetchData = (newChartConfig: ChartConfig | null = null) => {
  if (newChartConfig !== null) {
    localChartConfig = newChartConfig;
    dirtyChartConfig = true;
  } else if (dirtyChartConfig) {
    newChartConfig ??= localChartConfig
  }

  // For new charts, send the configuration on the first load
  if (newChartConfig === null && chartConfig.id === newChartId) {
    newChartConfig = chartConfig;
    newChartId = null;
  }

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

      loadError = false;
    })
    .catch((error) => {
      console.error(error);
      loadError = true;
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

<div class="flex flex-col px-6 p-4 bg-white border border-night-50 {isEditingChart && "xl:full-width xl:flex-row xl:justify-center xl:items-start"} gap-4">
  {#if isEditingChart}
    <div class="mt-12">
      <ChartEditor
        {canDangerouslyUseSql}
        {chartConfig}
        reloadChartData={reloadChartData}
        onClose={() => (isEditingChart = false)}
        onSave={saveChartConfig}
      />
    </div>
  {/if}

  <div class="grow min-w-0 flex flex-col gap-4">
    <div class={isEditingChart ? "flex-1 min-w-0 max-w-256" : ""}>
      <div class="mb-4">
        <h2 class="text-night-950 text-xl font-semibold text-center">{chartConfig.title}</h2>
        {#if localChartConfig.description}
          <p class="whitespace-pre-wrap w-max max-w-full mx-auto px-2 lg:px-12">{localChartConfig.description}</p>
        {/if}
      </div>
      {#if viewData}
        <StaticDataTable chartConfig={localChartConfig} {data} />
      {:else}
        {#if localChartConfig.type === "line"}
          <LineChart chartConfig={localChartConfig} {data} />
        {:else if localChartConfig.type === "bar"}
          <BarChart chartConfig={localChartConfig} {data} />
        {/if}
      {/if}
    </div>

    {#if loadError}
      <div class="p-2 bg-dawn-50 border border-dawn-200 text-dawn-700">
        <p>Something went wrong when trying to load the chart data.</p>
      </div>
    {/if}

    <div class="flex flex-wrap gap-2 items-center">
      {#if editingEnabled && !isEditingChart}
        <button type="button" onclick={() => (isEditingChart = true)}>Edit</button>
        <button type="button" onclick={onDuplicate}>Duplicate</button>
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

      <button type="button" onclick={() => fetchData()}>Refresh</button>
      <button type="button" onclick={() => (viewData = !viewData)}>{viewData ? "Show chart" : "Show data"}</button>
    </div>
  </div>
</div>
