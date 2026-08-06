<script lang="ts">
const {
  value,
  onToggle,
  labelOn = "YES",
  labelOff = "NO",
} : {
  value: boolean;
  onToggle: () => void;
  labelOn?: string;
  labelOff?: string;
} = $props();

const handleCheckboxChange = (e: Event) => {
  e.preventDefault();
  onToggle();
}
</script>

<input type="checkbox" class="sr-only" checked={value} onchange={handleCheckboxChange} />
<button
  type="button"
  aria-label="toggle checkbox"
  class="
    unstyled
    my-1
    relative
    h-6 w-13
    border rounded-full overflow-hidden
    {value ? "border-ice-600 bg-ice-50" : "border-dawn-600 bg-dawn-50"}
    cursor-pointer
  "
  onclick={onToggle}
>
  <span class="
    absolute top-1/2 left-0.75
    transition-all -translate-y-1/2
    size-4.5 rounded-full shadow-inner
    {value ? "bg-ice-300 translate-x-6.5" : "bg-dawn-300"}
  "></span>
  <span
    class="
      absolute top-1/2 -left-5
      transition-all -translate-y-1/2
      text-[0.625rem] font-light leading-none text-ice-600
      {value ? "translate-x-6.5" : ""}
    "
    aria-hidden={!value}
  >{labelOn}</span>
  <span
    class="
      absolute top-1/2 -right-4.75
      transition-all -translate-y-1/2
      text-[0.625rem] font-light leading-none text-dawn-600
      {value ? "" : "-translate-x-6.5"}
    "
    aria-hidden={value}
  >{labelOff}</span>
</button>
