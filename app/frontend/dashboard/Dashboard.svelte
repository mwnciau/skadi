<script lang="ts">
  import Tabs from "./Tabs.svelte";
  import LineChart from "./dashboardElements/LineChart.svelte";
  import type { DashboardConfig } from "../types.d.ts";

  let dashboards = $state<DashboardConfig[]>(
    JSON.parse(document.querySelector<HTMLElement>("[data-dashboard-config]")?.dataset?.dashboardConfig!),
  );

  let selectedTab = $state<string>(dashboards[0].id);
  let selectedDashboard = $derived(dashboards.find(dashboard => dashboard.id === selectedTab));

  const newTab = () => {
    let id = crypto.randomUUID();
    dashboards.push({
      id: id,
      title: `Dashboard ${dashboards.length + 1}`,
      children: [],
    });
    selectedTab = id;
  }
</script>

<Tabs
  dashboards={dashboards}
  selectedTab={selectedTab}
  selectTab={tab => selectedTab = tab}
  newTab={newTab}
/>
<main class="w-full max-w-256 mx-auto flex flex-col gap-4 pt-8">
  {#each selectedDashboard?.children as chart}
    <LineChart chartConfig={chart} />
  {/each}
</main>
