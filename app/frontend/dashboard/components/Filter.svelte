<script lang="ts">
import type { Snippet } from "svelte";
import Icon from "./Icon.svelte";
import Switch from "./Switch.svelte";

let {
  type = "text",
  model,
  key,
  children,
  description = null,
  selectOptions = null,
  leftLabel,
  rightLabel,
  leftValue = null,
  rightValue = null,
  switchIndeterminate = false,
  allowEmpty = false,
  trimOnBlur = false,
  ...attributes
} : {
  type?: "contenteditable" | "date" | "select" | "switch" | "text" | "textarea";
  model: Record<string,unknown>;
  key: string;
  leftLabel?: string;
  rightLabel?: string;
  leftValue?: unknown;
  rightValue?: unknown;
  switchIndeterminate?: boolean,

  allowEmpty?: boolean;
  trimOnBlur?: boolean;

  children: Snippet;
  description?: string | Snippet | null;
  selectOptions?: (string | {label?: string, value: string})[] | Snippet | null;
  [key: string]: unknown;
} = $props();

type StringEvent = Event & {
  currentTarget: EventTarget & (HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement | HTMLParagraphElement);
};

const switchValue = $derived.by(() => {
  if (switchIndeterminate && model[key] !== rightValue && model[key] !== leftValue) {
    return null;
  }

  return (model[key] === rightValue || (rightValue === null && model[key] === undefined));
});

let persistDelayMs = $derived(["date", "text", "textarea", "contenteditable"].includes(type) ? 1000 : 250);
let debounceTimeout: number;
let debounceValue: string;
let persistValue = () => {
  if (debounceValue || allowEmpty) {
    model[key] = debounceValue;
  } else {
    delete model[key];
  }
}

const setString = (event: StringEvent) => {
  debounceValue = type === "contenteditable" ? event.currentTarget.innerText : (event.currentTarget as HTMLInputElement).value;

  if (debounceTimeout) {
    clearTimeout(debounceTimeout);
  }
  debounceTimeout = setTimeout(persistValue, persistDelayMs);
}

const toggleSwitch = () => {
  if (switchValue) {
    if (leftValue === null) {
      delete model[key];
    } else {
      model[key] = leftValue;
    }
  } else if (switchValue === null) {
      model[key] = rightValue;
  } else {
    if (switchIndeterminate || rightValue === null) {
      delete model[key];
    } else {
      model[key] = rightValue;
    }
  }
}

const onBlur = () => {
  if (debounceTimeout) {
    clearTimeout(debounceTimeout);
    persistValue();
  }

  if (trimOnBlur && typeof model[key] === "string") {
    model[key] = model[key].trim();
  }
}

const contentEditableSync = (node: HTMLElement, value: unknown) => {
  node.innerText = (value as string | undefined) ?? "";

  return {
    update(value: string) {
      // Only update the contenteditable if it's not focused
      if (document.activeElement !== node) {
        node.innerText = value ?? "";
      }
    }
  }
}
</script>

{#snippet clearButton()}
  {#if model[key]}
    <button
      type="button"
      class="unstyled text-night-800 hover:text-black hover:bg-night-50 p-2 cursor-pointer"
      onclick={() => { delete model[key] }}>
      <Icon name="delete" />
    </button>
  {/if}
{/snippet}

<!-- biome-ignore lint/a11y/noLabelWithoutControl: the control is added by the snippets -->
<label>
  {@render children()}

  {#if type === "contenteditable"}
    <p
      contenteditable
      onblur={onBlur}
      oninput={setString}
      use:contentEditableSync={model[key]}
      class="mt-1 whitespace-pre-wrap"
      {...attributes}
    >{model[key]}</p>
  {:else if type === "date"}
    <div class="flex gap-1 items-center">
      <input
        type="date"
        onblur={onBlur}
        oninput={setString}
        value={model[key]}
        class="w-max"
      >
      {@render clearButton()}
    </div>
  {:else if type === "select"}
    <select
      onblur={onBlur}
      oninput={setString}
      value={model[key] ?? ""}
    >
      {#if Array.isArray(selectOptions)}
        {#each selectOptions as option}
          {#if typeof option === "string"}
            <option>{option}</option>
          {:else}
            <option value={option.value}>{option.label ?? option.value}</option>
          {/if}
        {/each}
      {:else}
        {@render selectOptions?.()}
      {/if}
    </select>
  {:else if type === "switch"}
    <div class="flex items-center gap-2 font-normal">
      {leftLabel}
      <Switch
        value={switchValue}
        onToggle={toggleSwitch}
        labelOff={leftLabel ? "" : undefined}
        labelOn={rightLabel ? "" : undefined}
      />
      {rightLabel}
    </div>
  {:else if type === "text"}
    <div class="flex gap-1 items-center">
      <input
        type="text"
        onblur={onBlur}
        oninput={setString}
        value={model[key]}
      >
      {@render clearButton()}
    </div>
  {:else if type === "textarea"}
    <textarea
      onblur={onBlur}
      oninput={setString}
      {...attributes}
    >{model[key]}</textarea>
  {/if}

  {#if typeof description === "string"}
    <span class="help-text">
      {description}
    </span>
  {:else}
    {@render description?.()}
  {/if}
</label>