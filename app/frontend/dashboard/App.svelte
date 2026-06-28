<script lang="ts">
  import Tabs from "./Tabs.svelte";
  import Chart from "./Chart.svelte";

  let dashboards = $state(JSON.parse(document.querySelector("[data-dashboard-config]").dataset.dashboardConfig));

  let selectedTab = $state<string>(dashboards[0].id);
  let selectedDashboard = $derived(dashboards.find(d => d.id === selectedTab));

  const newTab = () => {
    let id = crypto.randomUUID();
    dashboards.push({
      id: id,
      name: `Dashboard ${dashboards.length + 1}`,
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
<main class="w-full max-w-256 mx-auto">
  {#each selectedDashboard.children as chart}
    <Chart chartConfig={chart} />
  {/each}
</main>
