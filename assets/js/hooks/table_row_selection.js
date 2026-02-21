export const TableRowSelection = {
  mounted() {
    this.selectedIds = new Set();
    this.lastSelectionKey = "";
    this.pushSelectionDebounced = () => {
      clearTimeout(this.pushSelectionTimer);
      this.pushSelectionTimer = setTimeout(() => {
        this.pushSelectionChanged();
      }, 250);
    };

    this.handleChange = (event) => {
      const table = this.getTable();
      if (!table) return;

      const selectAllCheckbox = this.getSelectAllCheckbox(table);
      if (!selectAllCheckbox) return;

      if (event.target === selectAllCheckbox) {
        this.setAllRowsChecked(table, selectAllCheckbox.checked);
      } else {
        this.syncSelectionFromCheckbox(event.target);
      }

      this.updateSelectionUI();
      this.pushSelectionDebounced();
    };

    this.handleClick = (event) => {
      const clearButton = event.target.closest("[data-clear-selection]");
      if (!clearButton) return;

      event.preventDefault();

      const table = this.getTable();
      if (!table) return;

      this.selectedIds.clear();
      this.setAllRowsChecked(table, false);

      const selectAllCheckbox = this.getSelectAllCheckbox(table);
      if (selectAllCheckbox) {
        selectAllCheckbox.checked = false;
        selectAllCheckbox.indeterminate = false;
      }

      this.updateSelectionUI();
      this.pushSelectionDebounced();
    };

    this.el.addEventListener("change", this.handleChange);
    this.el.addEventListener("click", this.handleClick);
    this.syncVisibleRowsFromSelection();
    this.updateSelectionUI();
    this.pushSelectionChanged();
  },

  updated() {
    this.syncVisibleRowsFromSelection();
    this.updateSelectionUI();
  },

  destroyed() {
    this.el.removeEventListener("change", this.handleChange);
    this.el.removeEventListener("click", this.handleClick);
    clearTimeout(this.pushSelectionTimer);
  },

  getTable() {
    return this.el.querySelector("table");
  },

  getSelectAllCheckbox(table) {
    return table.querySelector('thead input[type="checkbox"][name="select-all"]');
  },

  getRowCheckboxes(table) {
    return Array.from(
      table.querySelectorAll('tbody input[type="checkbox"][name^="select-session-"]'),
    );
  },

  setAllRowsChecked(table, checked) {
    this.getRowCheckboxes(table).forEach((checkbox) => {
      checkbox.checked = checked;
      this.syncSelectionFromCheckbox(checkbox);
    });
  },

  getSessionId(checkbox) {
    if (!checkbox?.name) return null;

    const match = checkbox.name.match(/^select-session-(.+)$/);
    return match ? match[1] : null;
  },

  syncSelectionFromCheckbox(checkbox) {
    const sessionId = this.getSessionId(checkbox);
    if (!sessionId) return;

    if (checkbox.checked) {
      this.selectedIds.add(sessionId);
    } else {
      this.selectedIds.delete(sessionId);
    }
  },

  syncVisibleRowsFromSelection() {
    const table = this.getTable();
    if (!table) return;

    this.getRowCheckboxes(table).forEach((checkbox) => {
      const sessionId = this.getSessionId(checkbox);
      if (!sessionId) return;

      checkbox.checked = this.selectedIds.has(sessionId);
    });
  },

  updateSelectionUI() {
    const table = this.getTable();
    if (!table) return;

    const rowCheckboxes = this.getRowCheckboxes(table);
    const visibleSelectedCount = rowCheckboxes.filter((checkbox) => checkbox.checked).length;
    const selectedCount = this.selectedIds.size;
    const totalCount = rowCheckboxes.length;

    const selectAllCheckbox = this.getSelectAllCheckbox(table);
    if (selectAllCheckbox) {
      selectAllCheckbox.checked = totalCount > 0 && visibleSelectedCount === totalCount;
      selectAllCheckbox.indeterminate = visibleSelectedCount > 0 && visibleSelectedCount < totalCount;
    }

    const selectedCountElement = this.el.querySelector("[data-selected-count-number]");
    if (selectedCountElement) {
      selectedCountElement.textContent = String(selectedCount);
    }

    const selectedActions = this.el.querySelector("[data-selected-actions]");
    if (selectedActions) {
      selectedActions.classList.toggle("hidden", selectedCount === 0);
      selectedActions.classList.toggle("flex", selectedCount > 0);
    }
  },

  pushSelectionChanged() {
    const sessionIds = Array.from(this.selectedIds);
    const selectionKey = sessionIds.slice().sort().join(",");

    if (selectionKey === this.lastSelectionKey) return;

    this.lastSelectionKey = selectionKey;
    this.pushEvent("selected_sessions_changed", { session_ids: sessionIds });
  },
};
