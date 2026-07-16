<script lang="ts">
import Tabs from "./Tabs.svelte";
import LineChart from "./dashboardElements/LineChart.svelte";
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
</script>

<Tabs
  dashboards={dashboards}
  selectedTab={selectedTab}
  selectTab={tab => selectedTab = tab}
  newTab={newTab}
/>
<main class="w-full max-w-256 mx-auto flex flex-col gap-4 pt-8">
  {#each selectedDashboard?.children as chart, index}
    <LineChart
      chartConfig={chart}
      onDelete={() => deleteChart(index)}
      startEditing={chartIdToEdit === chart.id}
    />
  {/each}

  <div class="flex justify-center items-center py-8 mt-8 border border-dashed border-black/20">
    <button onclick={addChart}>Add chart</button>
  </div>
</main>
