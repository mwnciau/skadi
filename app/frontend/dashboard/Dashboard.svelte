<script lang="ts">
import { untrack } from "svelte";
import type { DashboardTabConfig, TabFilters } from "../types.d.ts";
import Filter from "./components/Filter.svelte";
import ChartWrapper from "./dashboardElements/ChartWrapper.svelte";
import TabEditor from "./editors/TabEditor.svelte";
import { saveDashboard } from "./helpers/requestHandler";
import Tabs from "./Tabs.svelte";

const callingScript = document.querySelector<HTMLElement>("[data-dashboard-config]") as HTMLElement;

let tabs = $state<DashboardTabConfig[]>(
  JSON.parse(callingScript.dataset.dashboardConfig as string),
);
const canEdit = callingScript.dataset.canEdit === "true";
const canDangerouslyUseSql = callingScript.dataset.canDangerouslyUseSql === "true";

let selectedTab = $state<string>(tabs[0].id);
let selectedTabConfig = $derived(tabs.find(dashboard => dashboard.id === selectedTab) as DashboardTabConfig);

// untrack: these just define the default state and aren't meant to be tracked
let tabFilters: TabFilters = $state(untrack(() => ({
  date_from: selectedTabConfig.date_from,
  date_to: selectedTabConfig.date_to,
})));

let chartIdToEdit: string | null = $state(null);
let editingEnabled: boolean = $state(false);

let saving: boolean = $state(false);
let saveError: boolean = $state(false);

const selectTab = (tab: string) => {
  selectedTab = tab;
  tabFilters = {
    date_from: selectedTabConfig.date_from,
    date_to: selectedTabConfig.date_to,
  };
}

const newTab = (newTitle: string | null = null) => {
  let id = crypto.randomUUID();
  tabs.push({
    id: id,
    title: newTitle ?? `Tab ${tabs.length + 1}`,
    description: "",
    children: [],
  });
  selectedTab = id;
}

const addChart = () => {
  const uuid = crypto.randomUUID();
  chartIdToEdit = uuid;

  selectedTabConfig.children.push({
    id: uuid,
    type: "line",
    title: "New chart",
    time_series: "weekly",
    datasets: [{
      id: crypto.randomUUID(),
      type: "visits",
      label: "Dataset 1",
    }],
  })
}
const deleteChart = (index: number) => {
  selectedTabConfig.children.splice(index, 1);
}

const duplicateChart = (index: number) => {
  const newChart = $state.snapshot(selectedTabConfig.children[index]);
  // Note: the datasets in the new chart will have the same ids as the datasets in the copied chart, but this isn't problematic because datasets are never referenced directly apart from their chart.
  newChart.id = crypto.randomUUID();
  chartIdToEdit = newChart.id;
  newChart.title = `Copy of ${newChart.title}`

  selectedTabConfig.children.splice(index + 1, 0, newChart);
}

const moveChartUp = (index: number) => {
  if (index === 0) {
    return;
  }

  // Splice returns the items that were removed, so this overwrites `index - 1` with `index`, then sets `index` to the removed item
  selectedTabConfig.children[index] = selectedTabConfig.children.splice(index - 1, 1, selectedTabConfig.children[index])[0];
}

const moveChartDown = (index: number) => {
  if (index >= selectedTabConfig.children.length - 1) {
    return;
  }

  // Splice returns the items that were removed, so this overwrites `index` with `index + 1`, then sets `index + 1` to the removed item
  selectedTabConfig.children[index + 1] = selectedTabConfig.children.splice(index, 1, selectedTabConfig.children[index + 1])[0];
}

const onDelete = () => {
  const currentIndex = tabs.indexOf(selectedTabConfig);

  if (tabs.length <= 1) {
    newTab("Tab 1");
  } else {
    const nextIndex = currentIndex === 0 ? 1 : currentIndex - 1;
    selectedTab = tabs[nextIndex].id;
  }

  tabs.splice(currentIndex, 1);
}

let saveTimeout: number | null = null;
const save = () => {
  saving = true;

  if (saveTimeout !== null) {
    clearTimeout(saveTimeout);
    saveTimeout = null;
  }

  saveDashboard(tabs)
    .then(() => {
      saving = false;
      saveError = false;
    })
    .catch(error => {
      saving = false;
      saveError = true;
      console.error("Failed to save dashboard", error);

      saveTimeout = setTimeout(() => {
        save();
        saveTimeout = null;
      }, 10000)
    });
}

let isMounted = false;
$effect(() => {
  if (!isMounted) {
    // Deep read tabs so it's marked as a dependency
    JSON.stringify(tabs);

    isMounted = true;

    return;
  }

  save();
});
</script>

<Tabs
  dashboards={tabs}
  selectedTab={selectedTab}
  selectTab={selectTab}
  newTab={newTab}
/>
<main class="w-full max-w-256 mx-auto flex flex-col gap-12 pt-4">
  {#if saving}
    <div class="fixed bottom-2 right-2 z-10 p-2 bg-ice-50 border border-ice-200 text-ice-700">
      <p>Saving your changes...</p>
    </div>
  {:else if saveError}
    <div class="fixed bottom-2 right-2 z-10 p-2 bg-dawn-50 border border-dawn-200 text-dawn-700">
      <p>Something went wrong when trying to save the dashboard. Retrying in 10 seconds...</p>
    </div>
  {/if}

  <div class="flex justify-between items-start">
    <div class="grow flex flex-col gap-4">
      {#if editingEnabled}
        {#key selectedTab}
          <TabEditor tabConfig={selectedTabConfig} {onDelete} />
        {/key}
      {:else}
        {#if selectedTabConfig.description}
          <p class="whitespace-pre">{selectedTabConfig.description}</p>
        {/if}

        <div class="flex gap-2 items-center">
          Showing data from
          <Filter type="date" model={tabFilters} key="date_from" hideLabel>
            <span class="sr-only">Date from</span>
          </Filter>
          to
          <Filter type="date" model={tabFilters} key="date_to" hideLabel>
            <span class="sr-only">Date to</span>
          </Filter>
        </div>
      {/if}
    </div>

    {#if canEdit}
      <button type="button" onclick={() => (editingEnabled = !editingEnabled)}>
        {editingEnabled ? "Finish" : "Enable"} editing
      </button>
    {/if}
  </div>

  {#each selectedTabConfig?.children as chartConfig, index (chartConfig.id)}
    <ChartWrapper
      {canDangerouslyUseSql}
      {chartConfig}
      {editingEnabled}
      {tabFilters}
      bind:newChartId={chartIdToEdit}
      onDelete={() => deleteChart(index)}
      onDuplicate={() => duplicateChart(index)}
      onMoveUp={index !== 0 ? (() => moveChartUp(index)) : null}
      onMoveDown={index !== selectedTabConfig.children.length - 1 ? (() => moveChartDown(index)) : null}
      onSave={(newChartConfig) => selectedTabConfig.children[index] = newChartConfig}
    />
  {/each}

  {#if editingEnabled}
    <div class="flex justify-center items-center py-8 mt-8 border border-dashed border-black/20">
      <button type="button" onclick={addChart}>Add chart</button>
    </div>
  {/if}
</main>
