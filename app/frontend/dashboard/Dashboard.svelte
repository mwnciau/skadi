<script lang="ts">
import Tabs from "./Tabs.svelte";
import ChartWrapper from "./dashboardElements/ChartWrapper.svelte";
import type { DashboardConfig } from "../types.d.ts";

let dashboards = $state<DashboardConfig[]>(
  JSON.parse(document.querySelector<HTMLElement>("[data-dashboard-config]")?.dataset?.dashboardConfig!),
);

let selectedTab = $state<string>(dashboards[0].id);
let selectedDashboard = $derived(dashboards.find(dashboard => dashboard.id === selectedTab));


// Intentionally left state-less because this will be a one-off thing when a chart is added or duplicated
let chartIdToEdit: string | null = null;

const newTab = () => {
  let id = crypto.randomUUID();
  dashboards.push({
    id: id,
    title: `Dashboard ${dashboards.length + 1}`,
    children: [],
  });
  selectedTab = id;
}

const addChart = () => {
  const uuid = crypto.randomUUID();
  chartIdToEdit = uuid;

  selectedDashboard.children.push({
    id: uuid,
    type: "line",
    title: "New chart",
    group: "week",
    datasets: [{
      id: crypto.randomUUID(),
      type: "visits",
      label: "Dataset 1",
    }],
  })
}
const deleteChart = (index: number) => {
  selectedDashboard.children.splice(index, 1);
}

const duplicateDataset = (index: number) => {
  const newChart = $state.snapshot(selectedDashboard.children[index]);
  // Note: the dataset ids will be still be the same between the datasets, but changing them potentially breaks and SQL datasets, so we just accept that datasets in different graphs might have the same ID
  newChart.id = crypto.randomUUID();
  chartIdToEdit = newChart.id;
  newChart.title = `Copy of ${newChart.title}`

  selectedDashboard.children.splice(index + 1, 0, newChart);
}

const moveUp = (index: number) => {
  if (index === 0) {
    return;
  }

  // Splice returns the items that were removed, so this overwrites `index - 1` with `index`, then sets `index` to the removed item
  selectedDashboard.children[index] = selectedDashboard.children.splice(index - 1, 1, selectedDashboard.children[index])[0];
}

const moveDown = (index: number) => {
  if (index >= selectedDashboard.children.length - 1) {
    return;
  }

  // Splice returns the items that were removed, so this overwrites `index` with `index + 1`, then sets `index + 1` to the removed item
  selectedDashboard.children[index + 1] = selectedDashboard.children.splice(index, 1, selectedDashboard.children[index + 1])[0];
}
</script>

<Tabs
  dashboards={dashboards}
  selectedTab={selectedTab}
  selectTab={tab => selectedTab = tab}
  newTab={newTab}
/>
<main class="w-full max-w-256 mx-auto flex flex-col gap-4 pt-8">
  {#each selectedDashboard?.children as chart, index (chart.id)}
    <ChartWrapper
      chartConfig={chart}
      onDelete={() => deleteChart(index)}
      startEditing={chartIdToEdit === chart.id}
      onDuplicate={() => duplicateDataset(index)}
      onMoveUp={index !== 0 ? (() => moveUp(index)) : null}
      onMoveDown={index !== selectedDashboard.children.length - 1 ? (() => moveDown(index)) : null}
      onSave={(newChartConfig) => selectedDashboard.children[index] = newChartConfig}
    />
  {/each}

  <div class="flex justify-center items-center py-8 mt-8 border border-dashed border-black/20">
    <button onclick={addChart}>Add chart</button>
  </div>
</main>
