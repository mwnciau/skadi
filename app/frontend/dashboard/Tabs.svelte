<script lang="ts">
  import type { DashboardTabConfig } from "../types.d.ts";

  let { dashboards, newTab, selectedTab, selectTab }: {
    dashboards: DashboardTabConfig[],
    newTab: () => void,
    selectedTab: string,
    selectTab: (id: string) => void,
  } = $props();
</script>

<header class="mt-4 px-4">
  <nav>
    {#each dashboards as dashboard, index}
      <button type="button" class="{dashboard.id === selectedTab ? "selected" : ""}" onclick={() => selectTab(dashboard.id)}>{dashboard.title ? dashboard.title : `Tab ${index + 1}`}</button>
    {/each}
    <button type="button" class="font-bold" onclick={() => newTab()}>＋</button>
  </nav>
</header>
