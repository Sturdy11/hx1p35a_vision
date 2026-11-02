"""Refresh the distribution's file integrity index after recording validation."""
from pathlib import Path
import hashlib, json

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT/'report/package_manifest.json'
files = []
for path in sorted(ROOT.rglob('*')):
    rel = path.relative_to(ROOT)
    if not path.is_file() or path == TARGET or set(rel.parts) & {'.git', 'out', '__pycache__'}:
        continue
    files.append(dict(file=rel.as_posix(), sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                      bytes=path.stat().st_size))
TARGET.write_text(json.dumps(dict(format=1, files=files), indent=2)+'\n', encoding='utf-8')
print('Indexed '+str(len(files))+' distribution files')
