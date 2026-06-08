<script lang="ts">
  import Tabs from "./Tabs.svelte";

  let selectedTab = $state<string>('Dashboard 1');
  let tabs = $state<string[]>(["Dashboard 1"]);

  const newTab = () => {
    tabs.push(`Dashboard ${tabs.length + 1}`);
    selectedTab = tabs[tabs.length - 1];
  }
</script>

<Tabs selectedTab={selectedTab} tabs={tabs} selectTab={tab => selectedTab = tab} newTab={newTab} />
<main class="w-full max-w-256 mx-auto">
  skadoobiedop
</main>
