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

// untrack: this is manually updated by fetchData
let localChartConfig = $state(untrack(() => chartConfig));

// Make this shallow state using $state.raw. We don't care how the charting library uses it, only that it's notified when the whole dataset is changed
let data : ChartData = $state.raw([]);

const fetchData = (newChartConfig: ChartConfig | null = null) => {
  localChartConfig = newChartConfig ?? chartConfig;

  if (newChartConfig === null && chartConfig.id === newChartId) {
    // For new charts, send the configuration on the first load
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

<div class="flex flex-col {isEditingChart && "xl:full-width xl:flex-row xl:justify-center xl:items-start"} gap-4">
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

    <div class="flex gap-2">
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

      <button type="button" onclick={() => (viewData = !viewData)}>{viewData ? "Show Graph" : "Show Data"}</button>
    </div>
  </div>
</div>
