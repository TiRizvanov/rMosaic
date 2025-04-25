// inst/htmlwidgets/mosaic.js
HTMLWidgets.widget({
  name: "mosaic",
  type: "output",
  factory: function(el, width, height) {
    console.log("[mosaic] — factory() called — element, size:", el, width, height);
    let pending = {};
    function shinyConnector(wid) {
      return {
        query: function(q) {
          return new Promise((resolve, reject) => {
            let reqId = "q" + Math.random().toString(36).substr(2,9);
            pending[reqId] = {resolve, reject};
            Shiny.setInputValue(
              `${wid}_mosaic_query`,
              {request: reqId, sql: q.sql, type: q.type || "json"},
              {priority:"event"}
            );
          });
        }
      };
    }
    function registerHandler(wid) {
      Shiny.addCustomMessageHandler(`${wid}_mosaic_response`, message => {
        let cb = pending[message.request];
        if (!cb) return;
        if (message.error) cb.reject(new Error(message.error));
        else             cb.resolve(message.data);
        delete pending[message.request];
      });
    }
    return {
      renderValue: async function(x) {
        const wid = x.widgetId;
        console.log(`[mosaic][${wid}] — renderValue() invoked with payload:`, x);

        // 1) Load vgplot & mosaic-spec
        let vgplot, mosaicSpec;
        try {
          console.log(`[mosaic] → loading mosaic-spec and vgplot libraries`);
          vgplot     = await import("https://esm.sh/@uwdata/vgplot@0.15.0");
          mosaicSpec = await import("https://esm.sh/@uwdata/mosaic-spec@0.15.0");
          console.log(`[mosaic] → libraries loaded successfully`);

          if (vgplot.registerMarks) {
            console.log(`[mosaic] → registering marks`);
            vgplot.registerMarks();
          } else {
            console.warn(`[mosaic] ⚠ registerMarks not available`);
          }
        } catch(err) {
          console.error(`[mosaic][${wid}] Library load failed:`, err);
          console.error("Error stack:", err.stack);
          el.innerText = "Failed to load Mosaic libraries.";
          return;
        }

        // 2) Register Shiny connector & load extensions in DuckDB
        console.log(`[mosaic][${wid}] ← registerHandler()`);
        registerHandler(wid);
        let conn = shinyConnector(wid);
        console.log(`[mosaic][${wid}] → setting databaseConnector`);
        vgplot.coordinator().databaseConnector(conn);

        // Add delay before proceeding to help prevent race conditions
        console.log(`[mosaic][${wid}] → waiting for initialization to complete...`);
        await new Promise(resolve => setTimeout(resolve, 500));

        // auto-install/load httpfs + spatial
        try {
          console.log(`[mosaic][${wid}] → installing and loading extensions`);
          await vgplot.coordinator().exec([
            "INSTALL httpfs;",
            "LOAD httpfs;",
            "INSTALL spatial;",
            "LOAD spatial;"
          ]);
          console.log(`[mosaic][${wid}] ✓ extensions loaded`);
        } catch(err) {
          console.error(`[mosaic][${wid}] Extension installation/loading failed:`, err);
          console.error("Error stack:", err.stack);
          el.innerText = "Failed to load required DuckDB extensions.";
          return;
        }

        // 3) Clear old and parse spec
        el.innerHTML = "";
        try {
          let view;
          console.log(`[mosaic][${wid}] → parseSpec`, x.spec);

          if (x.specType === "esmText") {
            console.log(`[mosaic][${wid}] → handling ESM text spec`);
            let blob = new Blob([x.specText], {type:"application/javascript"});
            let url  = URL.createObjectURL(blob);
            let mod  = await import(url);
            view = mod.default;
            URL.revokeObjectURL(url);
            console.log(`[mosaic][${wid}] ✓ ESM module imported`);
          } else {
            // More explicit handling of JSON/YAML spec
            try {
              console.log(`[mosaic][${wid}] → parsing spec as ${x.specType}`);
              let ast = mosaicSpec.parseSpec(x.spec);
              console.log(`[mosaic][${wid}] ✓ AST:`, ast);

              console.log(`[mosaic][${wid}] → astToDOM`);
              let result = await mosaicSpec.astToDOM(ast);
              console.log(`[mosaic][${wid}] ✓ astToDOM result:`, result);

              view = result.element || result;
            } catch (specError) {
              console.error(`[mosaic][${wid}] Spec parsing error:`, specError);
              console.error("Error stack:", specError.stack);
              console.error("Spec that caused error:", JSON.stringify(x.spec, null, 2));
              throw specError;
            }
          }

          // Handle crossfilter error with a fallback
          if (view && typeof view.select !== 'function' && view.element && typeof view.element.select !== 'function') {
            console.warn(`[mosaic][${wid}] ⚠ Selection not available on view - this may cause problems with crossfilter`);
          }

          if (view instanceof HTMLElement) {
            console.log(`[mosaic][${wid}] → appending element`, view);
            el.appendChild(view);
          } else if (view && view.element instanceof HTMLElement) {
            console.log(`[mosaic][${wid}] → appending element from view`, view.element);
            el.appendChild(view.element);
          } else {
            console.error(`[mosaic][${wid}] ✗ View is not valid:`, view);
            throw new Error("Returned view is not an HTMLElement");
          }
        } catch(e) {
          console.error(`[mosaic][${wid}] Detailed render error:`, e);
          console.error("Error stack:", e.stack);
          console.error("Error message:", e.message);
          el.innerHTML = `<div style="color:red;padding:10px;">
            Error rendering visualization: ${e.message}<br/>
            <small>Check browser console for details.</small>
          </div>`;
        }
      },
      resize: function(w, h) {
        console.log(`[mosaic] — resize() called: ${w}×${h}`);
      }
    };
  }
});
