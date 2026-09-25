import { FileBlob, SpreadsheetFile } from '@oai/artifact-tool';

const inputPath = process.argv[2];
const input = await FileBlob.load(inputPath);
const workbook = await SpreadsheetFile.importXlsx(input);

const overview = await workbook.inspect({
  kind: 'workbook,sheet,table',
  maxChars: 12000,
  tableMaxRows: 20,
  tableMaxCols: 12,
  tableMaxCellChars: 120,
});
console.log('OVERVIEW');
console.log(overview.ndjson);

for (const sheet of workbook.worksheets.items) {
  const used = sheet.getUsedRange(true);
  if (!used) continue;
  const table = await workbook.inspect({
    kind: 'table',
    sheetId: sheet.name,
    range: used.address,
    maxChars: 50000,
    tableMaxRows: 500,
    tableMaxCols: 20,
    tableMaxCellChars: 160,
  });
  console.log(`SHEET ${sheet.name} ${used.address}`);
  console.log(table.ndjson);
}
