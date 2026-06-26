import "./dashboard.css";

import { mount } from "svelte"
import App from "./dashboard/App.svelte"

window.addEventListener('load', () => {
  mount(
    App,
    {
      target: document.getElementById("skadi-dashboard"),
    },
  );
});
