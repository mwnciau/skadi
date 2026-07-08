<script lang="ts">
  import type {Dataset, Filter} from "../../types";
import Switch from "../components/Switch.svelte";

const { dataset, onDelete, index }: {
  dataset: Dataset;
  onDelete: () => void;
  index: number;
} = $props();

const toggleVisible = () => {
  if (dataset.visible === false) {
    delete dataset.visible;
  } else {
    dataset.visible = false;
  }
}

const toggleVerified = () => {
  if (dataset.filters.verified) {
    delete dataset.filters.verified;
  } else {
    dataset.filters.verified = true;
  }
}

const setFilterString = (filter: keyof Filter, value: string) => {
  if (value) {
    dataset.filters[filter] = value;
  } else {
    delete dataset.filters[filter];
  }
}
</script>

<div class="flex flex-col gap-2 mt-2 border-l-4 border-night-700 pt-0.5 pb-2 px-4 max-w-124">
  <div class="flex justify-between">
    <p class="text-xs font-semibold text-night-700">Dataset {index + 1}</p>
    <button type="button" class="text-xs px-2 py-1 -mt-1 font-semibold bg-dawn-100" onclick={onDelete}>Delete dataset</button>
  </div>

  <label>
    Label
    <input type="text" bind:value={dataset.label} />
  </label>

  <label>
    Type
    <select bind:value={dataset.type}>
      <option value="visits">Visits</option>
      <option value="views">Views</option>
      <option value="percentage">Percentage</option>
    </select>
  </label>

  <label>
    Show on chart
    <Switch value={dataset.visible === false} onToggle={toggleVisible} />
  </label>

  <p class="mt-4 text-xs font-semibold text-ice-500">Filters</p>

  <label>
    Show only verified views
    <Switch value={dataset.filters?.verified === true} onToggle={toggleVerified} />
  </label>

  {#if dataset.type === "views"}
    <label>
      Path
      <input type="text" onkeyup={event => setFilterString("path", event.target.value)} value={dataset.filters?.path} />
    </label>
  {/if}
</div>
