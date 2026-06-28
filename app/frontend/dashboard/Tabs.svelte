<script lang="ts">
  let { dashboards, newTab, selectedTab, selectTab }: {
    dashboards: DashboardConfig[],
    newTab: () => void,
    selectedTab: string,
    selectTab: (id: string) => void,
  } = $props();
</script>

<header class="mt-4 px-4">
  <nav>
    {#each dashboards as dashboard}
      <button type="button" class="{dashboard.id === selectedTab ? "selected" : ""}" onclick={() => selectTab(dashboard.id)}>{dashboard.name}</button>
    {/each}
    <button type="button" class="font-bold" onclick={() => newTab()}>＋</button>
  </nav>
</header>
