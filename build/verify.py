"""Check distribution integrity, paths, HDL equivalence and released bitstreams."""
from pathlib import Path
import hashlib, html, json, re, sys, xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
LEX = re.compile(r'"(?:\\.|[^"\\])*"|\\[^\s]+|//[^\r\n]*|/\*[\s\S]*?\*/|[^\s]', re.M)
DIRECTIVE = re.compile(r'\b(?:synthesis|synopsys|pragma|translate_off|translate_on|syn_[a-z_]+)\b', re.I)

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def logic_digest(path):
    tokens = [m.group() for m in LEX.finditer(path.read_text(encoding='utf-8-sig'))
              if not m.group().startswith(('//', '/*')) or DIRECTIVE.search(m.group())]
    return hashlib.sha256(json.dumps(tokens, ensure_ascii=False).encode()).hexdigest()

def verify():
    snapshot = json.loads((ROOT/'report/package_manifest.json').read_text())
    for record in snapshot['files']:
        p = (ROOT/record['file']).resolve()
        assert p.is_relative_to(ROOT) and p.is_file(), record['file']
        assert digest(p) == record['sha256'], 'Changed package input: '+record['file']
    for p in ROOT.rglob('*'):
        rel = p.relative_to(ROOT)
        if set(rel.parts) & {'.git', 'out', '__pycache__'}: continue
        for part in rel.parts:
            assert part == 'README.md' or re.fullmatch(r'[a-z0-9_.-]+', part), rel
    project = ROOT/'build/project.al'
    text = project.read_text()
    refs = re.findall(r'<File Path="([^"]+)"', text)
    assert len(refs) == 84 and '<MODULE>design_top_wrapper116</MODULE>' in text
    for ref in refs:
        p = (project.parent/html.unescape(ref)).resolve()
        assert p.is_relative_to(ROOT) and p.is_file(), ref
    assert not re.search(r'[a-zA-Z]:[/\\]', text), 'Absolute project path'
    # Parse IP-XACT metadata; required implementation files are checked by TD.
    for p in (ROOT/'src').rglob('*.xml'):
        ET.parse(p)
    provenance = json.loads((ROOT/'report/source_map.json').read_text())
    cleaned = 0
    for row in provenance['files']:
        p = ROOT/row['file']
        assert digest(p) == row['sha256'], row['file']
        if row['comments_cleaned']:
            assert row['logic_tokens_equal']
            assert logic_digest(p) == row['logic_sha256'], row['file']
            cleaned += 1
    plan = json.loads((ROOT/'sim/cases.json').read_text())
    assert len(plan) == 29
    for case in plan:
        for ref in case['sources']+case['fixtures']:
            assert (ROOT/ref).is_file(), ref
        text = (ROOT/'report/baseline_sim'/(case['name']+'.log')).read_text(errors='replace')
        assert case['marker'] in text and not re.search(r'\*\* (?:Fatal|Error):', text), case['name']
    validation = json.loads((ROOT/'report/validation.json').read_text())
    assert validation['passed'] and len(validation['current_cases']) == 8
    for row in validation['current_cases']:
        assert row['passed'] and digest(ROOT/row['log']) == row['log_sha256']
        case = next(c for c in plan if c['name'] == row['case'])
        text = (ROOT/row['log']).read_text(errors='replace')
        assert case['marker'] in text and not re.search(r'\*\* (?:Fatal|Error):', text)
    elab = validation['elaboration']
    assert elab['passed'] and digest(ROOT/elab['log']) == elab['sha256']
    assert 'ELABORATION COMPLETE' in (ROOT/elab['log']).read_text()
    relocated = json.loads((ROOT/'report/relocation.json').read_text())
    assert relocated['passed'] and relocated['td_elaboration_passed'] and relocated['focus_simulation_passed']
    for record in relocated['evidence']:
        assert digest(ROOT/record['file']) == record['sha256']
    for p in ROOT.rglob('*.md'):
        if set(p.relative_to(ROOT).parts) & {'out', '.git'}: continue
        for link in re.findall(r'\]\(([^)]+)\)', p.read_text(encoding='utf-8')):
            if re.match(r'[a-z]+://|#', link): continue
            assert (p.parent/link.split('#')[0]).exists(), str(p)+': '+link
    release = json.loads((ROOT/'report/v116_baseline.json').read_text())
    for row in release['bitstreams']:
        p = ROOT/row['file']
        assert p.stat().st_size == row['bytes'] and digest(p) == row['sha256']
    result = dict(passed=True, project_references=len(refs), packaged_files=len(snapshot['files']),
                  cleaned_hdl_files=cleaned, available_simulation_cases=len(plan),
                  current_regression_cases=8, td_elaboration_passed=True,
                  bitstreams_unchanged=True, hardware_logic_unchanged=True)
    print(json.dumps(result, indent=2))
    return result

if __name__ == '__main__':
    verify()
