// mosaic.js (Revised v6)
// Helper function to decode base64 to Uint8Array
function base64ToUint8Array(base64) {
  try {
    const binary_string = atob(base64);
    const len = binary_string.length;
    const bytes = new Uint8Array(len);
    for (let i = 0; i < len; i++) {
      bytes[i] = binary_string.charCodeAt(i);
    }
    return bytes;
  } catch (e) {
    console.error("[mosaic] Failed to decode base64 string:", base64.substring(0, 100) + "...", e);
    throw e;
  }
}

// Helper function to convert row-oriented data (array of objects) to column-oriented data (object of arrays)
function convertRowOrientedToColumnOriented(rows) {
  if (!rows || rows.length === 0) {
    return {};
  }
  const columns = {};
  // Initialize columns based on keys from the first row
  const keys = Object.keys(rows[0]);
  for (const key of keys) {
    columns[key] = [];
  }
  // Populate column arrays
  for (const row of rows) {
    for (const key of keys) {
      // Ensure row has the key to avoid errors if data is ragged
      columns[key].push(row.hasOwnProperty(key) ? row[key] : null);
    }
  }
  return columns;
}

HTMLWidgets.widget({
  name: "mosaic",
  type: "output",
  factory: function(el, width, height) {
    console.log("[mosaic] — factory() called — element, size:", el, width, height);
    const pending = {};
    let widgetIdInstance = null;
    let handlerRegistered = false;
    let coordinator = null;

    function shinyConnector(wid) {
      return {
        query: function(q) {
          console.log(`[mosaic][${wid}] → shinyConnector sending query:`, q);
          return new Promise((resolve, reject) => {
            const reqId = "q" + Math.random().toString(36).substr(2, 9);
            pending[reqId] = { resolve, reject, queryType: q.type || "json" };
            Shiny.setInputValue(
              `${wid}_mosaic_query`,
              { request: reqId, sql: q.sql, type: q.type || "json" },
              { priority: "event" }
            );
          });
        }
      };
    }

    function registerHandler(wid) {
      if (handlerRegistered) {
        console.log(`[mosaic][${wid}] Handler already registered.`);
        return;
      }
      Shiny.addCustomMessageHandler(`${wid}_mosaic_response`, message => {
        console.log(`[mosaic][${wid}] ← shinyConnector received response:`, message);
        const cbEntry = pending[message.request];
        if (!cbEntry) {
          console.warn(`[mosaic][${wid}] Received response for unknown request:`, message.request);
          return;
        }

        const queryType = cbEntry.queryType;
        let resolvedData;

        if (message.error) {
          console.error(`[mosaic][${wid}] Error from Shiny for request ${message.request}:`, message.error);
          cbEntry.reject(new Error(message.error));
        } else {
          try {
            if (queryType === 'arrow') {
              console.log(`[mosaic][${wid}] → processing 'arrow' type response for request ${message.request}. Data type from Shiny: ${typeof message.data}`);
              if (typeof message.data === 'string') { // Base64 encoded Arrow IPC string
                const ipcBytes = base64ToUint8Array(message.data);
                if (window.flechette && typeof window.flechette.fromIPC === 'function') {
                  resolvedData = window.flechette.fromIPC(ipcBytes);
                  console.log(`[mosaic][${wid}] ✓ Deserialized flechette.Table from IPC string using flechette.fromIPC().`);
                } else {
                   throw new Error(`[mosaic][${wid}] window.flechette.fromIPC is not available.`);
                }
              } else if (Array.isArray(message.data)) { // JS array of objects
                console.warn(`[mosaic][${wid}] ⚠ Received JS array for 'arrow' query (request ${message.request}). Attempting to convert to flechette.Table using tableFromArrays.`);
                if (window.flechette && typeof window.flechette.tableFromArrays === 'function') {
                  const columnOrientedData = convertRowOrientedToColumnOriented(message.data);
                  resolvedData = window.flechette.tableFromArrays(columnOrientedData);
                  console.log(`[mosaic][${wid}] ✓ Converted JS array to flechette.Table using flechette.tableFromArrays().`);
                } else {
                  console.error(`[mosaic][${wid}] ✗ window.flechette.tableFromArrays utility not found. Passing JS array as is. This will likely cause issues.`);
                  resolvedData = message.data;
                }
              } else if (typeof message.data === 'object' && message.data !== null && message.data.constructor && (message.data.constructor.name === 'Table' || message.data.constructor.name === 'FlechetteTable')) { // Check for Arrow or Flechette Table
                console.log(`[mosaic][${wid}] Data for 'arrow' query appears to be an Arrow/Flechette Table object. Using as is. Constructor: ${message.data.constructor.name}`);
                resolvedData = message.data;
              } else {
                throw new Error(`[mosaic][${wid}] For 'arrow' type, expected base64 Arrow IPC string or JS array, but got: ${typeof message.data}`);
              }
              cbEntry.resolve(resolvedData);
            } else {
              console.log(`[mosaic][${wid}] → processing '${queryType}' type response for request ${message.request}.`);
              cbEntry.resolve(message.data);
            }
          } catch (e) {
            console.error(`[mosaic][${wid}] Error processing data in shinyConnector for request ${message.request}:`, e);
            cbEntry.reject(e);
          }
        }
        delete pending[message.request];
      });
      handlerRegistered = true;
      console.log(`[mosaic][${wid}] ✓ Custom message handler registered.`);
    }

    const widgetInstance = {
      renderValue: async function(x) {
        widgetIdInstance = x.widgetId;
        const wid = widgetIdInstance;
        console.log(`[mosaic][${wid}] — renderValue() invoked with payload:`, x);

        let vgplot, mosaicSpec;
        try {
          vgplot = window.vgplot;
          mosaicSpec = window.mosaicSpec;
          if (!vgplot || !mosaicSpec || !window.flechette) throw new Error("Bundled vgplot, mosaicSpec, or flechette not found on window object.");
          console.log(`[mosaic][${wid}] ✓ Libraries accessed. vgplot.registerMarks ${vgplot.registerMarks ? 'available' : 'NOT available (this might be ok)'}.`);

          if (!coordinator) {
            coordinator = vgplot.coordinator();
            console.log(`[mosaic][${wid}] ✓ Coordinator initialized.`);
          }
          coordinator.databaseConnector(shinyConnector(wid));
          console.log(`[mosaic][${wid}] ✓ DatabaseConnector set on coordinator.`);

        } catch (err) {
          console.error(`[mosaic][${wid}] Library or coordinator setup failed:`, err);
          el.innerText = "Failed to load Mosaic libraries or setup coordinator. Check console."; return;
        }

        if (!handlerRegistered) registerHandler(wid);

        if (x.input_tables) {
          console.log(`[mosaic][${wid}] → Processing input_tables from R:`, x.input_tables);
          for (const tableName in x.input_tables) {
            try {
              let tableData = x.input_tables[tableName];
              let finalTableData = tableData;

              if (typeof tableData === 'string') {
                console.log(`[mosaic][${wid}] Input table '${tableName}' is a string. Attempting to decode as Arrow IPC and convert to flechette.Table.`);
                const ipcBytes = base64ToUint8Array(tableData);
                if (window.flechette && typeof window.flechette.fromIPC === 'function') {
                  finalTableData = window.flechette.fromIPC(ipcBytes);
                  console.log(`[mosaic][${wid}] ✓ Decoded input table '${tableName}' to flechette.Table using flechette.fromIPC().`);
                } else {
                  throw new Error(`window.flechette.fromIPC not available to decode input table '${tableName}'.`);
                }
              } else if (Array.isArray(tableData)) {
                 console.log(`[mosaic][${wid}] Input table '${tableName}' is a JS array. Attempting flechette.Table conversion using tableFromArrays.`);
                 if (window.flechette && typeof window.flechette.tableFromArrays === 'function') {
                    try {
                        const columnOrientedData = convertRowOrientedToColumnOriented(tableData);
                        finalTableData = window.flechette.tableFromArrays(columnOrientedData);
                        console.log(`[mosaic][${wid}] ✓ Converted JS array for input table '${tableName}' to flechette.Table using tableFromArrays.`);
                    } catch (convErr) {
                        console.warn(`[mosaic][${wid}] ⚠ Failed to convert JS array for input table '${tableName}' to flechette.Table, using raw array. Error:`, convErr);
                        finalTableData = tableData;
                    }
                 } else {
                    console.error(`[mosaic][${wid}] ✗ window.flechette.tableFromArrays utility not found for input table '${tableName}'. Using raw array.`);
                    finalTableData = tableData;
                 }
              }
              coordinator.input(tableName, finalTableData);
              console.log(`[mosaic][${wid}] ✓ Registered input table '${tableName}' with coordinator. Type: ${finalTableData ? finalTableData.constructor.name : typeof finalTableData}`);
            } catch (e) {
              console.error(`[mosaic][${wid}] Error processing input table '${tableName}':`, e);
            }
          }
        }

        try {
          const defaultExtensions = ["INSTALL httpfs;", "LOAD httpfs;", "INSTALL spatial;", "LOAD spatial;"];
          await coordinator.exec(defaultExtensions);
          console.log(`[mosaic][${wid}] ✓ Default extensions loaded via coordinator.`);
          if (x.spec && x.spec.config && x.spec.config.extensions && Array.isArray(x.spec.config.extensions)) {
            const specExtensions = x.spec.config.extensions.flatMap(ext => [`INSTALL ${ext};`, `LOAD ${ext};`]);
            await coordinator.exec(specExtensions);
            console.log(`[mosaic][${wid}] ✓ Spec extensions loaded:`, x.spec.config.extensions);
          }
        } catch (err) {
          console.error(`[mosaic][${wid}] Extension loading failed:`, err);
          el.innerText = "Failed to load DuckDB extensions. Check console."; return;
        }

        el.innerHTML = "";
        try {
          console.log(`[mosaic][${wid}] → Parsing spec (type: ${x.specType}):`, x.spec);
          let view;
          if (x.specType === "esmText") {
            const blob = new Blob([x.specText], { type: "application/javascript" });
            const url = URL.createObjectURL(blob);
            const mod = await import(url); view = mod.default;
            URL.revokeObjectURL(url);
            console.log(`[mosaic][${wid}] ✓ ESM module imported.`);
          } else {
            const ast = mosaicSpec.parseSpec(x.spec);
            console.log(`[mosaic][${wid}] ✓ AST generated from spec.`);
            const result = await mosaicSpec.astToDOM(ast, { coordinator: coordinator });
            console.log(`[mosaic][${wid}] ✓ astToDOM result obtained.`);
            view = result.element || result;
          }

          if (view instanceof HTMLElement) el.appendChild(view);
          else if (view && view.element instanceof HTMLElement) el.appendChild(view.element);
          else throw new Error("Parsed view is not a renderable HTMLElement.");
          console.log(`[mosaic][${wid}] ✓ View appended to DOM.`);
        } catch (e) {
          console.error(`[mosaic][${wid}] Error during spec parsing or rendering:`, e);
          el.innerHTML = `<div style="color:red; padding:10px; font-family:sans-serif;"><h4>Mosaic Rendering Error</h4><p><strong>Message:</strong> ${e.message}</p><pre style="white-space:pre-wrap; font-size:0.8em; background:#f0f0f0; padding:5px; border:1px solid #ccc;">${e.stack}</pre></div>`;
        }
      },
      resize: function(w, h) {
        const wid = widgetIdInstance;
        console.log(`[mosaic][${wid || 'unknown'}] — resize() called: ${w}×${h}.`);
      }
    };
    return widgetInstance;
  }
});
