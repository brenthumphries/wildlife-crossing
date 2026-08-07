/* Wildlife Crossing — progressive enhancement only.
 *
 * Nothing here renders content. Every page is fully readable with JavaScript
 * disabled; this file only adds filtering and search to the encyclopedia
 * index, which ships with all entries visible in the HTML.
 */
(function () {
  "use strict";

  var index = document.querySelector("[data-entry-index]");
  if (!index) return;

  var items = Array.prototype.slice.call(index.querySelectorAll("[data-kind]"));
  var tools = document.querySelector("[data-index-tools]");
  if (!tools || items.length === 0) return;

  // The controls are inert without JS, so they are only revealed once we run.
  tools.hidden = false;

  var search = tools.querySelector("input[type='search']");
  var buttons = Array.prototype.slice.call(tools.querySelectorAll(".filter-btn"));
  var status = document.querySelector("[data-index-status]");
  var activeKind = "all";

  function normalise(value) {
    return (value || "").toLowerCase().trim();
  }

  function apply() {
    var term = normalise(search ? search.value : "");
    var shown = 0;

    items.forEach(function (item) {
      var kindMatch = activeKind === "all" || item.getAttribute("data-kind") === activeKind;
      var haystack = normalise(item.getAttribute("data-search") || item.textContent);
      var termMatch = term === "" || haystack.indexOf(term) !== -1;
      var visible = kindMatch && termMatch;

      item.hidden = !visible;
      if (visible) shown += 1;
    });

    if (status) {
      if (shown === 0) {
        status.textContent = "No entries match that search.";
        status.hidden = false;
      } else if (term === "" && activeKind === "all") {
        status.hidden = true;
        status.textContent = "";
      } else {
        status.textContent =
          "Showing " + shown + (shown === 1 ? " entry." : " entries.");
        status.hidden = false;
      }
    }
  }

  buttons.forEach(function (button) {
    button.addEventListener("click", function () {
      activeKind = button.getAttribute("data-filter") || "all";
      buttons.forEach(function (other) {
        other.setAttribute("aria-pressed", String(other === button));
      });
      apply();
    });
  });

  if (search) {
    search.addEventListener("input", apply);
    // Escape clears the field, matching the game's "Escape exits" convention.
    search.addEventListener("keydown", function (event) {
      if (event.key === "Escape" && search.value !== "") {
        search.value = "";
        apply();
      }
    });
  }

  apply();
})();
