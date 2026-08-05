<script lang="ts">
const { page, perPage, totalItems, setPage, class: className = "" } : {
  page: number;
  perPage: number;
  totalItems: number;
  setPage: (newPage: number) => void;
  class?: string;
} = $props();

const totalPages = $derived(Math.ceil(totalItems / perPage))

const paginationPages = $derived.by(() => {
  const paginationPages: (string|number)[] = [];

  if (page > 3) paginationPages.push(1);
  if (page > 4) paginationPages.push("...");

  const loopMaxPages = Math.min(page + 2, totalPages);
  for (let p = Math.max(1, page - 2); p <= loopMaxPages; p++) {
    paginationPages.push(p);
  }

  if (page < totalPages - 3) paginationPages.push("...");
  if (page < totalPages - 2) paginationPages.push(totalPages);

  return paginationPages;
});
</script>

{#if totalPages > 1}
  <div class="grid grid-flow-col grid-cols-fr gap-2 items-baseline w-max mx-auto {className}">
    {#each paginationPages as p}
      {#if p === "..."}
        <p class="text-gray-500 leading-none">&hellip;</p>
      {:else if p === page}
        <button
          class="ghost bg-night-700 text-white"
          disabled
        >{p}</button>
      {:else}
        <button
          class="ghost"
          onclick={() => setPage(p as number)}
        >{p}</button>
      {/if}
    {/each}
  </div>
{/if}
