// Loads every widget written by export-widgets.R in headless Chromium over a
// local http server (fetch() of relative URLs does not work from file://) and
// checks that DuckDB-WASM built the table from the exported payload and that
// the dot mark rendered one circle per row.
// Usage: PLAYWRIGHT_ROOT=/dir/containing/node_modules node tests/browser/wasm-payloads.cjs /absolute/export-dir
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const http = require('node:http');

const playwrightRoot = process.env.PLAYWRIGHT_ROOT;
assert(playwrightRoot, 'Set PLAYWRIGHT_ROOT to a directory whose node_modules contains playwright');
const {chromium} = require(require.resolve('playwright', {paths: [playwrightRoot]}));

const loadedLine = {
  'file/arrows': "Loaded Arrow IPC table 'points'",
  'file/parquet': "Loaded Parquet table 'points'",
  'inline/arrows': "Loaded inline Arrow IPC table 'points'",
  'inline/parquet': "Loaded inline Parquet table 'points'"
};

async function main() {
  assert(process.argv[2], 'Pass the export directory written by export-widgets.R');
  const root = await fs.realpath(process.argv[2]);
  const expected = JSON.parse(await fs.readFile(path.join(root, 'expected.json'), 'utf8'));
  const mime = {
    '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css',
    '.json': 'application/json', '.arrows': 'application/vnd.apache.arrow.stream',
    '.parquet': 'application/octet-stream'
  };
  const server = http.createServer(async (req, res) => {
    try {
      const file = await fs.realpath(path.resolve(root, '.' + decodeURIComponent(new URL(req.url, 'http://localhost').pathname)));
      if (!file.startsWith(root + path.sep)) { res.writeHead(403); res.end(); return; }
      const bytes = await fs.readFile(file);
      res.setHeader('Content-Type', mime[path.extname(file)] || 'application/octet-stream');
      res.end(bytes);
    } catch (err) {
      res.writeHead(404);
      res.end();
    }
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  const browser = await chromium.launch({headless: true});
  const reports = [];
  try {
    for (const widget of expected.widgets) {
      const context = await browser.newContext({viewport: {width: 800, height: 600}});
      const page = await context.newPage();
      const errors = [];
      const logs = [];
      page.on('pageerror', e => errors.push(String(e)));
      page.on('requestfailed', r => errors.push(r.url() + ': ' + (r.failure() || {}).errorText));
      page.on('console', m => {
        logs.push(m.text());
        if (m.type() === 'error') errors.push(m.text());
      });
      await page.goto(`${base}/${widget.file}`, {waitUntil: 'load', timeout: 120000});
      await page.waitForFunction(
        rows => document.querySelectorAll('svg circle').length === rows,
        expected.rows,
        {timeout: 120000}
      );
      const circles = await page.evaluate(() => document.querySelectorAll('svg circle').length);
      const line = loadedLine[`${widget.transport}/${widget.format}`];
      assert(line, `unknown payload kind ${widget.transport}/${widget.format}`);
      assert(logs.some(text => text.includes(line)), `${widget.file}: expected console line "${line}"`);
      const requested = await page.evaluate(() =>
        performance.getEntriesByType('resource').map(entry => entry.name.split('/').pop())
      );
      if (widget.transport === 'file') {
        assert(requested.includes(widget.payload_file), `${widget.file}: browser must fetch ${widget.payload_file}`);
      }
      assert.deepEqual(errors, [], `${widget.file}: browser errors`);
      await page.screenshot({path: path.join(root, widget.file.replace(/\.html$/, '.png'))});
      reports.push({...widget, circles, browser: browser.version(), payload_requested: widget.transport === 'file'});
      await context.close();
    }
    await fs.writeFile(path.join(root, 'browser-verification.json'), JSON.stringify(reports, null, 2) + '\n');
    console.log(`PASS: ${reports.length} widgets rendered ${expected.rows} points each from DuckDB-WASM payloads`);
    for (const report of reports) {
      console.log(`  ${report.file}: ${report.transport}/${report.format} via ${report.method}, ${report.circles} circles`);
    }
  } finally {
    await browser.close();
    server.close();
  }
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
