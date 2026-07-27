<script lang="ts">
import Filter from "../components/Filter.svelte";
import { DashboardTabConfig } from "../../types";

const {tabConfig, onDelete} = $props<{
  tabConfig: DashboardTabConfig;
  onDelete: () => void;
}>();

let confirmDelete: boolean = $state(false);
</script>

<Filter
  model={tabConfig}
  key="title"
  allowEmpty
  trimOnBlur
>
  Tab name
</Filter>

<Filter
  type="contenteditable"
  model={tabConfig}
  key="description"
  placeholder="Enter a description for this tab"
  trimOnBlur
>
  Tab description
</Filter>

<Filter
  type="date"
  model={tabConfig}
  key="date_from"
>
  Default date from
</Filter>

<Filter
  type="date"
  model={tabConfig}
  key="date_to"
>
  Default date to
</Filter>

<div class="flex gap-2 mt-4">
  {#if confirmDelete}
    <button type="button" class="bg-dawn-100" onclick={onDelete}>Yes, delete this dashboard and all its charts</button>
    <button type="button" class="ghost text-gray-600" onclick={() => (confirmDelete = false)}>Cancel</button>
  {:else}
    <button type="button" class="bg-dawn-100" onclick={() => (confirmDelete = true)}>Delete this tab</button>
  {/if}
</div>
