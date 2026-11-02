"""Run released V116 fixtures with a relocated, comment-cleaned source tree."""
from pathlib import Path
import argparse, hashlib, json, re, shutil, subprocess, time, zipfile

ROOT = Path(__file__).resolve().parents[1]
QUICK = ['focus116', 'wrapper116', 'packet116', 'gauze116',
         'white_stream116_l1', 'white_stream116_l2', 'fullscene116', 'jaws116']

def quote(value):
    assert not any(c in str(value) for c in '{}\n\r'), value
    return '{'+str(value).replace('\\', '/')+'}'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--vsim', default='vsim')
    parser.add_argument('--all', action='store_true', help='All 29 cases, including long 720p video')
    parser.add_argument('--cases', nargs='+')
    parser.add_argument('--out', type=Path, default=ROOT/'sim/out')
    args = parser.parse_args()
    plan = json.loads((ROOT/'sim/cases.json').read_text())
    selected = args.cases or ([c['name'] for c in plan] if args.all else QUICK)
    assert set(selected) <= {c['name'] for c in plan}, 'Unknown case'
    args.out.mkdir(parents=True, exist_ok=True)
    results = []
    for name in selected:
        case = next(c for c in plan if c['name'] == name)
        out = args.out/name
        out.mkdir(parents=True, exist_ok=True)
        for fixture in case['fixtures']:
            with zipfile.ZipFile(ROOT/fixture) as archive:
                for member in archive.namelist():
                    dest = (out/member).resolve()
                    assert dest.is_relative_to(out.resolve()), member
                    if member.endswith('.mem'):
                        dest.parent.mkdir(parents=True, exist_ok=True)
                        dest.write_bytes(archive.read(member))
        for header in (ROOT/'sim/cases'/name).glob('*.vh'):
            shutil.copy2(header, out/header.name)
        script = '\n'.join([
            'onerror {quit -code 1 -f}', 'onbreak {quit -code 1 -f}',
            'vlib work', 'vmap work work',
            'vlog -sv '+' '.join(case['defines']+[quote(ROOT/p) for p in case['sources']]),
            'vsim -onfinish exit work.'+case['top'], 'run -all', ''])
        (out/'run.tcl').write_text(script, encoding='utf-8')
        start = time.monotonic()
        with (out/'console.txt').open('w', encoding='utf-8') as console:
            proc = subprocess.run([args.vsim, '-c', '-do', 'run.tcl', '-l', 'test.log'],
                                  cwd=out, stdout=console, stderr=subprocess.STDOUT, timeout=7200)
        log = (out/'test.log').read_text(errors='replace') if (out/'test.log').exists() else ''
        passed = proc.returncode == 0 and case['marker'] in log and not re.search(r'\*\* (?:Fatal|Error):', log)
        result = dict(case=name, passed=passed, seconds=round(time.monotonic()-start, 2),
                      log=str((out/'test.log').relative_to(args.out)),
                      log_sha256=hashlib.sha256(log.encode()).hexdigest())
        results.append(result)
        (args.out/'results.json').write_text(json.dumps(results, indent=2))
        print(('PASS ' if passed else 'FAIL ')+name+' '+str(result['seconds'])+'s', flush=True)
        if not passed:
            raise SystemExit('See '+str(out/'console.txt'))
    print('PASS '+str(len(results))+' repository regression cases', flush=True)

if __name__ == '__main__':
    main()
