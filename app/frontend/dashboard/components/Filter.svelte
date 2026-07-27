<script lang="ts">
import type { Snippet } from "svelte";
import Switch from "./Switch.svelte";
import Icon from "./Icon.svelte";

let {
  type = "text",
  model,
  key,
  booleanDefault = false,
  children,
  description = null,
  selectOptions = null,
  leftLabel = null,
  rightLabel = null,
  leftValue = null,
  rightValue = null,
  allowEmpty = false,
  trimOnBlur = false,
  ...attributes
} = $props<{
  type?: "boolean" | "contenteditable" | "date" | "select" | "switch" | "text" | "textarea";
  model: object;
  key: string;
  booleanDefault?: true | false;
  leftLabel?: string;
  rightLabel?: string;
  leftValue?: string;
  rightValue?: string;

  allowEmpty?: boolean;
  trimOnBlur?: boolean;

  children: Snippet;
  description?: string | Snippet | null;
  selectOptions?: (string | {label?: string, value: string})[] | Snippet | null;
  [key: string]: unknown;
}>();

type StringEvent = Event & {
  currentTarget: EventTarget & (HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement);
};

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
  debounceValue = type === "contenteditable" ? event.currentTarget.innerText : event.currentTarget.value;

  if (debounceTimeout) {
    clearTimeout(debounceTimeout);
  }
  debounceTimeout = setTimeout(persistValue, 1000);
}

const toggleBoolean = () => {
  if (model[key] === !booleanDefault) {
    delete model[key];
  } else {
    model[key] = !booleanDefault;
  }
}

const toggleSwitch = () => {
  if (model[key] === rightValue) {
    if (leftValue === null) {
      delete model[key];
    } else {
      model[key] = leftValue;
    }
  } else {
    model[key] = rightValue;
  }
}

const onBlur = () => {
  if (debounceTimeout) {
    clearTimeout(debounceTimeout);
    persistValue();
  }

  if (trimOnBlur) {
    model[key] = model[key]?.trim();
  }
}

const contentEditableSync = (node: HTMLElement, value: string) => {
  node.innerText = value ?? "";

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

<label>
  {@render children()}

  {#if type === "boolean"}
    <Switch value={booleanDefault ? model[key] !== false : model[key] === true} onToggle={toggleBoolean} />
  {:else if type === "contenteditable"}
    <p
      contenteditable
      onblur={onBlur}
      oninput={setString}
      use:contentEditableSync={model[key]}
      class="mt-1 whitespace-pre"
      {...attributes}
    >{model[key]}</p>
  {:else if type === "date"}
    <div class="flex gap-1 items-center">
      <input
        type="date"
        oninput={setString}
        value={model[key]}
        class="w-max"
      >
      {@render clearButton()}
    </div>
  {:else if type === "select"}
    <select
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
      <Switch value={model[key] === rightValue} onToggle={toggleSwitch} />
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