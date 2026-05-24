// mosaic.js (Revised with fixed WASM data loading)
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

// Helper function to convert row-oriented data to column-oriented data
function convertRowOrientedToColumnOriented(rows) {
  if (!rows || rows.length === 0) {
    return {};
  }
  const columns = {};
  const keys = Object.keys(rows[0]);
  for (const key of keys) {
    columns[key] = [];
  }
  for (const row of rows) {
    for (const key of keys) {
      columns[key].push(row.hasOwnProperty(key) ? row[key] : null);
    }
  }
  return columns;
}

async function fetchArrowIPC(url) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to fetch Arrow IPC data from ${url}: ${response.status} ${response.statusText}`);
  }
  return new Uint8Array(await response.arrayBuffer());
}

function tableIsArrowUrl(tableData) {
  return tableData && typeof tableData === 'object' && typeof tableData.__arrow_url === 'string';
}

function canDecodeArrowIPC() {
  return window.flechette && typeof window.flechette.tableFromIPC === 'function';
}

// Helper function to format values for SQL
function formatSQLValue(value) {
  if (value === null || value === undefined) {
    return 'NULL';
  } else if (typeof value === 'string') {
    const escaped = value.replace(/'/g, "''");
    return `'${escaped}'`;
  } else if (typeof value === 'number') {
    return value.toString();
  } else if (typeof value === 'boolean') {
    return value ? 'TRUE' : 'FALSE';
  } else {
    const str = String(value);
    const escaped = str.replace(/'/g, "''");
    return `'${escaped}'`;
  }
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
    let wasmConnector = null;
    let useWasm = false;

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
      Shiny.addCustomMessageHandler(`${wid}_mosaic_response`, async message => {
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
              if (typeof message.data === 'string') {
                const ipcBytes = base64ToUint8Array(message.data);
                if (canDecodeArrowIPC()) {
                  resolvedData = window.flechette.tableFromIPC(ipcBytes);
                  console.log(`[mosaic][${wid}] ✓ Deserialized flechette.Table from IPC string using flechette.tableFromIPC().`);
                } else {
                  throw new Error(`[mosaic][${wid}] window.flechette.tableFromIPC is not available.`);
                }
              } else if (Array.isArray(message.data)) {
                console.warn(`[mosaic][${wid}] ⚠ Received JS array for 'arrow' query (request ${message.request}). Attempting to convert to flechette.Table using tableFromArrays.`);
                if (window.flechette && typeof window.flechette.tableFromArrays === 'function') {
                  const columnOrientedData = convertRowOrientedToColumnOriented(message.data);
                  resolvedData = window.flechette.tableFromArrays(columnOrientedData);
                  console.log(`[mosaic][${wid}] ✓ Converted JS array to flechette.Table using tableFromArrays().`);
                } else {
                  console.error(`[mosaic][${wid}] ✗ window.flechette.tableFromArrays utility not found. Passing JS array as is.`);
                  resolvedData = message.data;
                }
              } else if (typeof message.data === 'object' && message.data !== null && message.data.constructor && (message.data.constructor.name === 'Table' || message.data.constructor.name === 'FlechetteTable')) {
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
        useWasm = x.useWasm || false;
        console.log(`[mosaic][${wid}] — renderValue() invoked with payload:`, x);
        console.log(`[mosaic][${wid}] Using ${useWasm ? 'WASM' : 'R native'} DuckDB backend`);

        let vgplot, mosaicSpec;
        try {
          vgplot = window.vgplot;
          mosaicSpec = window.mosaicSpec;
          if (!vgplot || !mosaicSpec || !window.flechette) throw new Error("Bundled vgplot, mosaicSpec, or flechette not found on window object.");
          console.log(`[mosaic][${wid}] ✓ Libraries accessed.`);

          if (!coordinator) {
            coordinator = vgplot.coordinator();
            console.log(`[mosaic][${wid}] ✓ Coordinator initialized.`);
          }

          // Set up the appropriate connector
          if (useWasm) {
            if (window.vgplot.wasmConnector) {
              console.log(`[mosaic][${wid}] Initializing WASM connector via vgplot...`);
              try {
                wasmConnector = await window.vgplot.wasmConnector();
                coordinator.databaseConnector(wasmConnector);
                console.log(`[mosaic][${wid}] ✓ WASM connector initialized and set.`);
              } catch (e) {
                console.error(`[mosaic][${wid}] Failed to initialize WASM connector:`, e);
                console.log(`[mosaic][${wid}] Falling back to R backend...`);
                useWasm = false;
                coordinator.databaseConnector(shinyConnector(wid));
              }
            } else if (window.createWasmConnector) {
              console.log(`[mosaic][${wid}] Initializing custom WASM connector...`);
              try {
                wasmConnector = await window.createWasmConnector();
                coordinator.databaseConnector(wasmConnector);
                console.log(`[mosaic][${wid}] ✓ Custom WASM connector initialized and set.`);
              } catch (e) {
                console.error(`[mosaic][${wid}] Failed to initialize custom WASM connector:`, e);
                console.log(`[mosaic][${wid}] Falling back to R backend...`);
                useWasm = false;
                coordinator.databaseConnector(shinyConnector(wid));
              }
            } else {
              console.warn(`[mosaic][${wid}] WASM connector not available, falling back to R backend.`);
              useWasm = false;
              coordinator.databaseConnector(shinyConnector(wid));
            }
          } else {
            coordinator.databaseConnector(shinyConnector(wid));
            console.log(`[mosaic][${wid}] ✓ Shiny DatabaseConnector set on coordinator.`);
          }
        } catch (err) {
          console.error(`[mosaic][${wid}] Library or coordinator setup failed:`, err);
          el.innerText = "Failed to load Mosaic libraries or setup coordinator. Check console.";
          return;
        }

        if (!useWasm && !handlerRegistered) {
          registerHandler(wid);
        }

        // Handle input tables
        if (x.input_tables) {
          console.log(`[mosaic][${wid}] → Processing input_tables from R:`, x.input_tables);

          if (useWasm) {
            // For WASM, load data into DuckDB using SQL
            for (const tableName in x.input_tables) {
              try {
                let tableData = x.input_tables[tableName];

                if (tableIsArrowUrl(tableData)) {
                  const ipcBytes = await fetchArrowIPC(tableData.__arrow_url);
                  const conn = await wasmConnector.getConnection();
                  await conn.insertArrowFromIPCStream(ipcBytes, { name: tableName, create: true, schema: 'main' });
                  console.log(`[mosaic][${wid}] ✓ Loaded Arrow IPC table '${tableName}' into WASM DuckDB from ${tableData.__arrow_url}`);
                } else if (Array.isArray(tableData) && tableData.length > 0) {
                  // Determine columns from the first row
                  const columns = Object.keys(tableData[0]);

                  // Infer column types based on first row values
                  const columnTypes = columns.map(col => {
                    const val = tableData[0][col];
                    if (typeof val === 'number') return 'DOUBLE';
                    if (typeof val === 'string') return 'VARCHAR';
                    if (typeof val === 'boolean') return 'BOOLEAN';
                    return 'VARCHAR'; // Default to string
                  });

                  // Create table
                  const createTableSQL = `CREATE TABLE IF NOT EXISTS ${tableName} (${columns.map((col, i) => `"${col}" ${columnTypes[i]}`).join(', ')})`;
                  console.log(`[mosaic][${wid}] Executing SQL:`, createTableSQL);
                  await coordinator.exec([createTableSQL]);
                  console.log(`[mosaic][${wid}] Table '${tableName}' created.`);

                  // Insert data in batches to avoid large SQL statements
                  const batchSize = 100;
                  for (let i = 0; i < tableData.length; i += batchSize) {
                    const batch = tableData.slice(i, i + batchSize);
                    const values = batch.map(row => `(${columns.map(col => formatSQLValue(row[col])).join(', ')})`).join(', ');
                    const insertSQL = `INSERT INTO ${tableName} VALUES ${values}`;
                    console.log(`[mosaic][${wid}] Executing INSERT SQL for batch ${i / batchSize + 1}`);
                    await coordinator.exec([insertSQL]);
                  }

                  console.log(`[mosaic][${wid}] ✓ Created and populated table '${tableName}' in WASM DuckDB`);

                  // Verify table creation (optional debugging)
                  const result = await coordinator.query(`SELECT COUNT(*) FROM ${tableName}`, { type: 'json' });
                  let rowCount = 'unknown';
                  if (Array.isArray(result) && result.length > 0) {
                    rowCount = result[0]['count(*)'] ?? result[0].count ?? rowCount;
                  } else if (result && typeof result === 'object') {
                    if (Array.isArray(result.data) && result.data.length > 0) {
                      rowCount = result.data[0]['count(*)'] ?? result.data[0].count ?? rowCount;
                    } else if (result.columns && typeof result.columns === 'object') {
                      const countColumn = result.columns['count(*)'] ?? result.columns.count;
                      if (Array.isArray(countColumn) && countColumn.length > 0) {
                        rowCount = countColumn[0];
                      }
                    }
                  }
                  console.log(`[mosaic][${wid}] Table '${tableName}' has ${rowCount} rows.`);
                }
              } catch (e) {
                console.error(`[mosaic][${wid}] Error loading table '${tableName}' into WASM:`, e);
              }
            }
          } else {
            // For R backend, register tables with coordinator
            for (const tableName in x.input_tables) {
              try {
                let tableData = x.input_tables[tableName];
                let finalTableData = tableData;

                if (typeof tableData === 'string') {
                  console.log(`[mosaic][${wid}] Input table '${tableName}' is a string. Attempting to decode as Arrow IPC.`);
                  const ipcBytes = base64ToUint8Array(tableData);
                  if (canDecodeArrowIPC()) {
                    finalTableData = window.flechette.tableFromIPC(ipcBytes);
                    console.log(`[mosaic][${wid}] ✓ Decoded input table '${tableName}' to flechette.Table.`);
                  } else {
                    throw new Error(`window.flechette.tableFromIPC not available.`);
                  }
                } else if (Array.isArray(tableData)) {
                  console.log(`[mosaic][${wid}] Input table '${tableName}' is a JS array.`);
                  if (window.flechette && typeof window.flechette.tableFromArrays === 'function') {
                    try {
                      const columnOrientedData = convertRowOrientedToColumnOriented(tableData);
                      finalTableData = window.flechette.tableFromArrays(columnOrientedData);
                      console.log(`[mosaic][${wid}] ✓ Converted JS array to flechette.Table.`);
                    } catch (convErr) {
                      console.warn(`[mosaic][${wid}] ⚠ Failed to convert, using raw array.`, convErr);
                      finalTableData = tableData;
                    }
                  } else {
                    console.error(`[mosaic][${wid}] ✗ window.flechette.tableFromArrays not found.`);
                    finalTableData = tableData;
                  }
                }
                coordinator.input(tableName, finalTableData);
                console.log(`[mosaic][${wid}] ✓ Registered input table '${tableName}' with coordinator.`);
              } catch (e) {
                console.error(`[mosaic][${wid}] Error processing input table '${tableName}':`, e);
              }
            }
          }
        }

        // Load extensions (only for R backend)
        try {
          if (!useWasm) {
            const defaultExtensions = ["INSTALL httpfs;", "LOAD httpfs;", "INSTALL spatial;", "LOAD spatial;"];
            await coordinator.exec(defaultExtensions);
            console.log(`[mosaic][${wid}] ✓ Default extensions loaded via coordinator.`);

            if (x.spec && x.spec.config && x.spec.config.extensions && Array.isArray(x.spec.config.extensions)) {
              const specExtensions = x.spec.config.extensions.flatMap(ext => [`INSTALL ${ext};`, `LOAD ${ext};`]);
              await coordinator.exec(specExtensions);
              console.log(`[mosaic][${wid}] ✓ Spec extensions loaded:`, x.spec.config.extensions);
            }
          }
        } catch (err) {
          console.error(`[mosaic][${wid}] Extension loading failed:`, err);
        }

        // Render the visualization
        el.innerHTML = "";
        try {
          console.log(`[mosaic][${wid}] → Parsing spec (type: ${x.specType}):`, x.spec);
          let view;
          if (x.specType === "esmText") {
            // Wrap ESM code to make vgplot functions available
            // Import from window.vgplot and make all functions available in module scope
            const vgplotWrapper = `
              // Import vgplot from window object
              const vg = window.vgplot;
              
              // Make all vgplot functions available in module scope
              // This allows ESM code to use Param, vconcat, plot, etc. directly
              const Param = vg.Param;
              const vconcat = vg.vconcat;
              const hconcat = vg.hconcat;
              const plot = vg.plot;
              const voronoi = vg.voronoi;
              const hull = vg.hull;
              const delaunayMesh = vg.delaunayMesh;
              const dot = vg.dot;
              const frame = vg.frame;
              const menu = vg.menu;
              const hspace = vg.hspace;
              const vspace = vg.vspace;
              const width = vg.width;
              const height = vg.height;
              const inset = vg.inset;
              const regressionY = vg.regressionY;
              const raster = vg.raster;
              const rectY = vg.rectY;
              const from = vg.from;
              const loadParquet = vg.loadParquet;
              const loadCSV = vg.loadCSV;
              const loadJSON = vg.loadJSON;
              const loadArrow = vg.loadArrow;
              
              // Now execute the user's ESM code:
              ${x.specText}
            `;
            const blob = new Blob([vgplotWrapper], { type: "application/javascript" });
            const url = URL.createObjectURL(blob);
            const mod = await import(url);
            view = mod.default;
            URL.revokeObjectURL(url);
            console.log(`[mosaic][${wid}] ✓ ESM module imported with vgplot functions.`);
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
          el.innerHTML = `<div style="color:red; padding:10px; font-family:sans-serif;">
            <h4>Mosaic Rendering Error</h4>
            <p><strong>Message:</strong> ${e.message}</p>
            <pre style="white-space:pre-wrap; font-size:0.8em; background:#f0f0f0; padding:5px; border:1px solid #ccc;">${e.stack}</pre>
          </div>`;
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
