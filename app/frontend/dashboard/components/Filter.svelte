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
  showClear = true,
  trimOnBlur = false,
  class: className = "",
  ...attributes
} : {
  type?: "contenteditable" | "date" | "number" | "select" | "switch" | "string" | "text" | "textarea";
  model: Record<string,unknown>;
  key: string;
  leftLabel?: string;
  rightLabel?: string;
  leftValue?: unknown;
  rightValue?: unknown;
  switchIndeterminate?: boolean,

  allowEmpty?: boolean;
  showClear?: boolean;
  trimOnBlur?: boolean;

  children: Snippet;
  description?: string | Snippet | null;
  selectOptions?: (string | {label?: string, value: string})[] | Snippet | null;

  class?: string;
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

const clearIsVisible = $derived(showClear && model[key]);

let persistDelayMs = $derived(["date", "number", "text", "textarea", "contenteditable"].includes(type) ? 1000 : 250);
let debounceTimeout: number;
let debounceValue: string | number | null = null;
let persistValue = () => {
  if ((debounceValue !== null && debounceValue !== "") || allowEmpty) {
    model[key] = debounceValue;
  } else {
    delete model[key];
  }
}

const setString = (event: StringEvent) => {
  if (type === "contenteditable") {
    debounceValue = event.currentTarget.innerText;
  } else if (type === "number") {
    let value = (event.currentTarget as HTMLInputElement).value.trim();

    if (value.match(/^-?\d*\.?\d+$/)) {
      debounceValue = Number.parseFloat(value);
    } else {
      debounceValue = null;
    }
  } else {
    debounceValue = (event.currentTarget as HTMLInputElement).value;
  }

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

const clearValue = () => {
  if (debounceTimeout) {
    clearTimeout(debounceTimeout);
  }

  if ((type === "text" || type === "string") && allowEmpty) {
    model[key] = "";
  } else {
    delete model[key];
  }
}
</script>

{#snippet clearButton()}
  {#if clearIsVisible}
    <button
      type="button"
      class="
        unstyled
        absolute inset-0 left-auto p-2
        text-night-800 hover:text-black hover:bg-night-50
        cursor-pointer
      "
      onclick={clearValue}>
      <Icon name="clear" />
    </button>
  {/if}
{/snippet}

<!-- biome-ignore lint/a11y/noLabelWithoutControl: the control is added by the snippets -->
<label class={className}>
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
    <div class="relative w-max">
      <input
        type="date"
        onblur={onBlur}
        oninput={setString}
        value={model[key]}
        class="w-max {clearIsVisible ? "pr-8" : ""}"
      >
      {@render clearButton()}
    </div>
  {:else if type === "number"}
    <div class="relative w-max">
      <input
        type="number"
        onblur={onBlur}
        oninput={setString}
        value={model[key]}
        class="{clearIsVisible ? "pr-8" : ""}"
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
  {:else if type === "string" || type === "text"}
    <div class="relative flex">
      <input
        type="text"
        onblur={onBlur}
        oninput={setString}
        value={model[key]}
        class="grow {clearIsVisible ? "pr-8" : ""}"
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