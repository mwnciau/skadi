<script lang="ts">
import Icon from "./Icon.svelte";
import { untrack } from "svelte";

const {
  startOpen = false,
  wrapperClass = "border-night-700",
  title,
  children,
} = $props<{
  startOpen?: boolean;
}>();

// untrack: this is a one-time default that lets the parent control the state
let open = $state(untrack(() => startOpen));

export function close() {
  open = false;
}
</script>


<div class="border-l-4 {wrapperClass} pl-4 py-0.5">
  <button
    class="group w-full flex items-center unstyled cursor-pointer py-0.5"
    onclick={() => (open = !open)}
  >
    {@render title(open)}
    <Icon name={open ? "chevron_up" : "chevron_down"} size={24} class="text-ice-800 group-hover:text-black ml-auto" />
  </button>

  <div class="contents">
    <div class="grid transition-[grid-template-rows] ease-in-out overflow-hidden {open ? "grid-rows-[1fr]" : "grid-rows-[0fr]"}">
      <div class="flex flex-col gap-3 px-0.5 pb-2 mt-2 overflow-hidden">
        {@render children()}
      </div>
    </div>
  </div>
</div>