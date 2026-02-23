import Sortable from "sortablejs";

const SortableSections = {
  mounted() {
    this.sortable = new Sortable(this.el, {
      animation: 150,
      handle: "[data-drag-handle]",
      ghostClass: "opacity-30",
      dragClass: "shadow-lg",
      onEnd: () => {
        const order = Array.from(this.el.children)
          .map((el) => el.dataset.sectionId)
          .filter(Boolean);

        this.pushEvent("reorder_prompt_sections", { order });
      },
    });
  },
  destroyed() {
    if (this.sortable) {
      this.sortable.destroy();
    }
  },
};

export default SortableSections;
