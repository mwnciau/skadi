<script lang="ts">
  import type {Dataset} from "../../types";
import Switch from "../components/Switch.svelte";

const { dataset, onDelete, index }: {
  dataset: Dataset;
  onDelete: () => void;
  index: number;
} = $props();

const toggleFilterBoolean = (key: string, defaultValue = false) => {
  if (dataset[key] === !defaultValue) {
    delete dataset[key];
  } else {
    dataset[key] = !defaultValue;
  }
}

const setFilterString = (filter: string, value: string) => {
  if (value) {
    dataset[filter] = value;
  } else {
    delete dataset[filter];
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
    <Switch value={dataset.visible !== false} onToggle={() => toggleFilterBoolean("visible", true)} />
  </label>

  {#if dataset.type === "views" || dataset.type === "visits"}
    <p class="mt-4 text-xs font-semibold text-ice-500">Filters</p>


    <label>
      Show only verified {dataset.type}
      <Switch value={dataset?.verified === true} onToggle={() => toggleFilterBoolean("verified")} />
    </label>
  {/if}

  {#if dataset.type === "views"}
    <label>
      Split by
      <select onchange="{event => setFilterString("split_by", event.target.value)}" value={dataset?.split_by}>
        <option></option>
        <option value="controller">Controller</option>
        <option value="controller_action">Controller and action</option>
        <option value="path">Path</option>
        <option value="verb">Verb</option>
      </select>
    </label>

    <label>
      Path
      <input type="text" onkeyup={event => setFilterString("view_path", event.target.value)} value={dataset?.view_path} />
    </label>

    <label>
      Controller
      <input type="text" onkeyup={event => setFilterString("view_controller", event.target.value)} value={dataset?.view_controller} />
    </label>

    <label>
      Action
      <input type="text" onkeyup={event => setFilterString("view_action", event.target.value)} value={dataset?.view_action} />
    </label>

    <label>
      Verb
      <select onchange="{event => setFilterString("view_verb", event.target.value)}" value={dataset?.view_verb}>
        <option></option>
        <option>GET</option>
        <option>POST</option>
        <option>PUT</option>
        <option>PATCH</option>
        <option>DELETE</option>
      </select>
    </label>

    <p class="mt-4 text-xs font-semibold text-ice-500">Visit filters</p>

    <label>
      One view per visit
      <Switch value={dataset?.unique_visits === true} onToggle={() => toggleFilterBoolean("unique_visits")} />
    </label>
  {/if}

  {#if dataset.type === "visits" || dataset.type === "views"}
    <label>
      Visit tracking
      <select onchange="{event => setFilterString("visit_tracking", event.target.value)}" value={dataset?.visit_tracking}>
        <option value="">Show all visits</option>
        <option value="any">Show visits tracked by anonymity set or cookie</option>
        <option value="anonymity_set">Show visits tracked by anonymity set</option>
        <option value="cookie">Show visits tracked by cookie</option>
      </select>
    </label>
  {/if}
</div>
