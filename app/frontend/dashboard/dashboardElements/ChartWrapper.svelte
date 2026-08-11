<script lang="ts">
import { untrack } from "svelte";
import type {
  ChartConfig,
  ChartData,
  ChartFilters,
  ChartMetadata,
  RawChartResponseData,
  TabFilters,
  TableData
} from "../../types.d.ts";
import Icon from "../components/Icon.svelte";
import ChartEditor from "../editors/ChartEditor.svelte";
import processChartResponseData from "../helpers/processChartResponseData";
import { fetchChartData } from "../helpers/requestHandler";
import BarChart from "./BarChart.svelte";
import DynamicTable from "./DynamicTable.svelte";
import LineChart from "./LineChart.svelte";
import StaticDataTable from "./StaticDataTable.svelte";

let { canDangerouslyUseSql, chartConfig, editingEnabled, startOpen, tabFilters, onDelete, onDuplicate, onMoveUp, onMoveDown, onSave }: {
  canDangerouslyUseSql: boolean;
  chartConfig: ChartConfig;
  editingEnabled: boolean;
  tabFilters: TabFilters;
  startOpen: boolean;
  onDelete: () => void;
  onDuplicate: () => void;
  onMoveUp?: null | (() => void);
  onMoveDown?: null | (() => void);
  onSave: (newChartConfig: ChartConfig) => void;
} = $props();

// untrack: this is a one-time default that lets the parent control the state
let isEditingChart = $state(untrack(() => startOpen));

let viewData = $state(false);
let confirmDelete: boolean = $state(false);
let loadError = $state(false);
let loading = $state(false);

// untrack: this is manually updated by fetchData
let localChartConfig = $state(untrack(() => chartConfig));

let chartFilters: ChartFilters = $state({});
let chartMetadata: ChartMetadata = $state({});

// Make this shallow state using $state.raw. We don't care how the charting library uses it, only that it's notified when the whole dataset is changed
let data : ChartData | TableData = $state.raw([]);

const fetchData = (newChartConfig: ChartConfig) => {
  loading = true;

  return fetchChartData(
    // While the chart is being edited, always send the chart config
    isEditingChart ? newChartConfig : chartConfig.id,
    tabFilters,
    chartFilters,
  )
    .then((response) => {
      localChartConfig = newChartConfig;

      if (localChartConfig.type === "table") {
        chartMetadata.resultOffset = response.resultOffset;
        chartMetadata.resultCount = response.resultCount;
        data = response.data as TableData;
      } else {
        data = processChartResponseData(localChartConfig, response.data as RawChartResponseData);
      }

      loadError = false;
    })
    .catch((error) => {
      console.error(error);
      loadError = true;

      // Let downstream handlers also catch errors
      throw error;
    })
    .finally(() => {
      loading = false;
    });
}

const reloadChartData = (localChartConfig: ChartConfig) => {
  return fetchData(localChartConfig);
}

const saveChartConfig = (newChartConfig: ChartConfig) => {
  onSave(newChartConfig);
  localChartConfig = newChartConfig;

  isEditingChart = false;
}

$effect(() => {
  // Ensure this effect is run when chartFilters or tabFilters changes
  JSON.stringify(tabFilters);
  JSON.stringify(chartFilters);

  untrack(() => {
    fetchData(localChartConfig);
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
        <h2 class="text-night-950 text-xl font-semibold text-center">{localChartConfig.title}</h2>
        {#if localChartConfig.description}
          <p class="whitespace-pre-wrap w-max max-w-full mx-auto px-2 lg:px-12">{localChartConfig.description}</p>
        {/if}
      </div>
      <div class="relative">
        {#if data.length === 0}
          <div class="aspect-video border border-ice-100">
            <p class="absolute top-1/2 left-1/2 -translate-1/2 text-gray-600">
              No data to display
            </p>
          </div>
        {:else if localChartConfig.type === "table"}
          <DynamicTable chartConfig={localChartConfig} {chartFilters} {chartMetadata} data={data as TableData} {loading} />
        {:else if viewData && data.length !== 0}
          <StaticDataTable chartConfig={localChartConfig} data={data as ChartData} />
        {:else if localChartConfig.type === "line"}
          <LineChart data={data as ChartData} />
        {:else if localChartConfig.type === "bar"}
          <BarChart chartConfig={localChartConfig} data={data as ChartData} />
        {/if}
      </div>
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

      <button type="button" onclick={() => fetchData(localChartConfig)}>Refresh</button>
      {#if data.length !== 0 && chartConfig.type !== "table"}
        <button type="button" onclick={() => (viewData = !viewData)}>{viewData ? "Show chart" : "Show data"}</button>
      {/if}
    </div>
  </div>
</div>
