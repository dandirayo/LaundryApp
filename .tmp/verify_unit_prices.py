import re, openpyxl
from pathlib import Path
book = openpyxl.load_workbook(r'C:\Users\ASUS\Documents\All-Laundry\Harga Satuan Laundry Update Final.xlsx', data_only=True, read_only=True)
ws = book['Harga Satuan']
text = Path(r'C:\Users\ASUS\Documents\GitHub\LaundryApp\laundry_app_flutter\lib\shared\default_service_catalog.dart').read_text(encoding='utf-8')
pat = re.compile(r"_catalogService\(\s*'([^']+)',\s*'([^']*)',\s*'([^']*)',\s*'([^']*)',\s*'([^']*)',\s*(\d+),\s*(\d+)", re.S)
catalog = {m.group(1): {'category':m.group(2),'item':m.group(3),'variant':m.group(4),'unit':m.group(5),'price':int(m.group(6))} for m in pat.finditer(text)}
checked=[]; unmapped=[]; mismatch=[]
for row in ws.iter_rows(min_row=2, values_only=True):
    no, subcat, item, variant, unit, old, new, note, sid = row
    if new is None or str(unit).lower() == 'kg' or subcat == 'Laundry Kiloan':
        continue
    candidates = [sid, f'{sid}-cuci-setrika']
    found = next((c for c in candidates if c in catalog), None)
    if not found:
        unmapped.append((no,sid,item,variant,new))
        continue
    checked.append(found)
    if catalog[found]['price'] != int(new):
        mismatch.append((no,found,catalog[found]['price'],int(new)))
print({'verified_rows':len(checked),'unmapped':unmapped,'mismatch':mismatch,'catalog_count':len(catalog)})