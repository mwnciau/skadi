import "./dashboard.css";

import { mount } from "svelte";
import Dashboard from "./dashboard/Dashboard.svelte";

window.addEventListener("load", () => {
  const root = document.getElementById("skadi-dashboard") as HTMLDivElement;

  mount(Dashboard, { target: root });
});
