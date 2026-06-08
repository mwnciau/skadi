<script lang="ts">
  let { newTab, selectedTab, selectTab, tabs }: {
    newTab: () => void,
    selectedTab: string,
    selectTab: (tab: string) => void,
    tabs: string[],
  } = $props();
</script>

<header class="mt-2 px-4">
  <nav>
    {#each tabs as tab}
      <button type="button" class="{tab === selectedTab ? 'selected' : ''}" onclick={() => selectTab(tab)}>{tab}</button>
    {/each}
    <button type="button" class="font-bold" onclick={() => newTab()}>＋</button>
  </nav>
</header>
