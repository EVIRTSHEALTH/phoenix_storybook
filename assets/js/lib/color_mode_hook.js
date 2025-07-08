/*
This hook is meant to:
- remember, with local storage, which color mode has been selected by the user
- toggle psb color_mode on the HTML root element (which will change colors of the storybook itself, 
not the component's colors)
- push to the storybook the selected color mode, and the actual color mode (when selected value 
is system, it will send dark or light depending on the browser current prefers-color-scheme).
*/

let self;

export const ColorModeHook = {
  mounted() {
    self = this;
    window.addEventListener("psb:set-color-mode", this.onSetColorMode);
    document.documentElement.dataset.theme = this.actualColorMode(this.selectedColorMode());

    window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => {
      const selectedMode = this.selectedColorMode();
      const actualMode = this.actualColorMode(selectedMode);

      this.pushEvent("psb-set-color-mode", {
        selected_mode: selectedMode,
        mode: actualMode,
      });
      this.toggleColorModeClass(actualMode);
    });
  },

  destroyed() {
    window.removeEventListener("psb:set-color-mode", this.onSetColorMode);
  },

  selectedColorMode() {
    return localStorage.getItem("psb_selected_color_mode") || "system";
  },

  actualColorMode(selectedMode) {
    if (selectedMode === "system" && window.matchMedia("(prefers-color-scheme: dark)").matches) {
      return "dark";
    }
    if (selectedMode === "dark") {
      return "dark";
    }
    return "light";
  },
  toggleColorModeClass: (mode) => {
    if ("colorMode" in document.documentElement.dataset) {
      if (mode === "dark") {
        document.documentElement.classList.add("dark");
      } else {
        document.documentElement.classList.remove("dark");
      }
    }
  },
  onSetColorMode: (e) => {
    const selectedMode = e.detail.mode || "system";
    localStorage.setItem("psb_selected_color_mode", selectedMode);

    const actualMode = self.actualColorMode(selectedMode);
    // mimic "phx:set-theme" event, by just assigning data-theme to document
    document.documentElement.dataset.theme = actualMode;

    self.pushEvent("psb-set-color-mode", {
      selected_mode: selectedMode,
      mode: actualMode,
    });
    self.toggleColorModeClass(actualMode);
  },
};

const selectedMode = ColorModeHook.selectedColorMode();
const actualMode = ColorModeHook.actualColorMode(selectedMode);
ColorModeHook.toggleColorModeClass(actualMode);
