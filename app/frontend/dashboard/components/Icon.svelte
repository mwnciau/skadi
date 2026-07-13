<script lang="ts">
const ICONS = {
  chevron_down: "M480-344 240-584l56-56 184 184 184-184 56 56-240 240Z",
  chevron_up: "M480-528 296-344l-56-56 240-240 240 240-56 56-184-184Z",
  plus: "M440-440H200v-80h240v-240h80v240h240v80H520v240h-80v-240Z",
} as const;

const { name, size = null, class: className = "", ...attributes } = $props<{
  name: keyof typeof ICONS;
  size?: number | string | null;
  class?: string;
}>();

const sizeStyleString = $derived.by(() => {
  if (typeof size === "number" || (typeof size === "string" && size.match(/^\d+$/))) {
    return `${size}px`;
  }

  if (typeof size === "string") {
      return size;
  }

  return "1em";
});
</script>

<svg
  xmlns="http://www.w3.org/2000/svg"
  viewBox="0 -960 960 960"
  class="fill-current {className}"
  style:height={sizeStyleString}
  style:width={sizeStyleString}
  {...attributes}
><path d={ICONS[name]}/></svg>