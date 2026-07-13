<script lang="ts">
import type {Dataset} from "../../types";
import Icon from "../components/Icon.svelte";
import Switch from "../components/Switch.svelte";

const { dataset, index, startOpen = false, onDelete, onDuplicate, onMoveUp, onMoveDown }: {
  dataset: Dataset;
  index: number;
  startOpen?: boolean;
  onDelete: () => void;
  onDuplicate: () => void;
  onMoveUp?: null | (() => void);
  onMoveDown?: null | (() => void);
} = $props();

let open = $state(startOpen);
const toggleOpen = () => {
  open = !open;
}

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

const duplicate = () => {
  onDuplicate();
  open = false;
}
</script>

<div class="border-l-4 border-night-700 pl-4 py-0.5">
  <button class="group w-full flex justify-between items-center unstyled cursor-pointer py-0.5" onclick={toggleOpen}>
    <p class="text-sm font-semibold text-night-700 group-hover:text-night-800">
      Dataset {index + 1}
      {#if !open}
        - {dataset.label}
      {/if}
    </p>
    <Icon name={open ? "chevron_up" : "chevron_down"} size={24} class="text-ice-800 group-hover:text-black" />
  </button>

  <div class="contents">
    <div class="grid transition-[grid-template-rows] ease-in-out overflow-hidden {open ? "grid-rows-[1fr]" : "grid-rows-[0fr]"}">
      <div class="flex flex-col gap-3 pb-2 mt-2 overflow-hidden">
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

        {#if dataset.visible !== false}
          <label>
            Axis
            <div class="flex items-center gap-2 font-normal">
              Left
              <Switch
                value={dataset.axis === "right"}
                onToggle={() => setFilterString("axis", dataset.axis === "right" ? "" : "right")}
                labelOn=""
                labelOff=""
              />
              Right
            </div>
          </label>
        {/if}

        {#if dataset.type === "views" || dataset.type === "visits"}
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

        <div class="flex flex-row gap-2 mt-4">
          <button type="button" class="sm bg-dawn-100" onclick={onDelete}>Delete</button>
          <button type="button" class="sm" onclick={duplicate}>Duplicate</button>
          {#if onMoveUp !== null }
            <button type="button" class="sm px-1" onclick={onMoveUp}><Icon name="chevron_up" size={24} /></button>
          {/if}
          {#if onMoveDown !== null }
            <button type="button" class="sm px-1" onclick={onMoveDown}><Icon name="chevron_down" size={24} /></button>
          {/if}
        </div>
      </div>
    </div>
  </div>
</div>
