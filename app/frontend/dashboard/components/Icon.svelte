<script lang="ts">
const ICONS = {
  chevron_down: "M480-344 240-584l56-56 184 184 184-184 56 56-240 240Z",
  chevron_up: "M480-528 296-344l-56-56 240-240 240 240-56 56-184-184Z",
  clear: "m256-200-56-56 224-224-224-224 56-56 224 224 224-224 56 56-224 224 224 224-56 56-224-224-224 224Z",
  delete: "m376-300 104-104 104 104 56-56-104-104 104-104-56-56-104 104-104-104-56 56 104 104-104 104 56 56Zm-96 180q-33 0-56.5-23.5T200-200v-520h-40v-80h200v-40h240v40h200v80h-40v520q0 33-23.5 56.5T680-120H280Zm400-600H280v520h400v-520Zm-400 0v520-520Z",
  plus: "M440-440H200v-80h240v-240h80v240h240v80H520v240h-80v-240Z",
} as const;

const { name, size = null, class: className = "", alt = null, ...attributes } : {
  name: keyof typeof ICONS;
  size?: number | string | null;
  class?: string;
  alt?: string | null;
} = $props();

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
><title>{alt ?? name}</title><path d={ICONS[name]}/></svg>
