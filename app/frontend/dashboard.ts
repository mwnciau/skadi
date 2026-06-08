import "./dashboard.css";

import { mount } from "svelte"
import Dashboard from "./dashboard/Dashboard.svelte"

window.addEventListener('load', () => {
  mount(
    Dashboard,
    {
      target: document.getElementById("skadi-dashboard"),
    },
  );
});
