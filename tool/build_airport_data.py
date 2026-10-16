"""Build Thai airport data from the AOT/DOA "Air Transport Statistics" CSV.

Usage:
    python tool/build_airport_data.py "E:/Downloads/Air_Transport_Statistics_External_Monthly(All_External_Data).csv"

Outputs:
    lib/data/thai_airports.dart       bundled airport list (offline fallback)
    backend/seed/firestore_seed.json  data for backend/scripts/seed_firestore.js

The CSV only contains airport traffic (movements / passengers / freight).
It has no airlines, routes, schedules or fares.
"""

import csv
import json
import sys
from collections import defaultdict
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# IATA -> (nameEn, nameTh, cityEn, cityTh)
THAI_NAMES = {
    'BKK': ('Suvarnabhumi', 'สุวรรณภูมิ', 'Bangkok', 'กรุงเทพฯ'),
    'DMK': ('Don Mueang', 'ดอนเมือง', 'Bangkok', 'กรุงเทพฯ'),
    'HKT': ('Phuket', 'ภูเก็ต', 'Phuket', 'ภูเก็ต'),
    'CNX': ('Chiang Mai', 'เชียงใหม่', 'Chiang Mai', 'เชียงใหม่'),
    'HDY': ('Hat Yai', 'หาดใหญ่', 'Hat Yai', 'หาดใหญ่'),
    'USM': ('Samui', 'สมุย', 'Ko Samui', 'เกาะสมุย'),
    'KBV': ('Krabi', 'กระบี่', 'Krabi', 'กระบี่'),
    'UTP': ('U-Tapao', 'อู่ตะเภา', 'Rayong-Pattaya', 'ระยอง-พัทยา'),
    'CEI': ('Mae Fah Luang Chiang Rai', 'แม่ฟ้าหลวง เชียงราย', 'Chiang Rai', 'เชียงราย'),
    'BFV': ('Buriram', 'บุรีรัมย์', 'Buriram', 'บุรีรัมย์'),
    'UTH': ('Udon Thani', 'อุดรธานี', 'Udon Thani', 'อุดรธานี'),
    'NST': ('Nakhon Si Thammarat', 'นครศรีธรรมราช', 'Nakhon Si Thammarat', 'นครศรีธรรมราช'),
    'PHS': ('Phitsanulok', 'พิษณุโลก', 'Phitsanulok', 'พิษณุโลก'),
    'URT': ('Surat Thani', 'สุราษฎร์ธานี', 'Surat Thani', 'สุราษฎร์ธานี'),
    'HHQ': ('Hua Hin', 'หัวหิน', 'Hua Hin', 'หัวหิน'),
    'LPT': ('Lampang', 'ลำปาง', 'Lampang', 'ลำปาง'),
    'MAQ': ('Mae Sot', 'แม่สอด', 'Mae Sot', 'แม่สอด'),
    'LOE': ('Loei', 'เลย', 'Loei', 'เลย'),
    'THS': ('Sukhothai', 'สุโขทัย', 'Sukhothai', 'สุโขทัย'),
    'UNN': ('Ranong', 'ระนอง', 'Ranong', 'ระนอง'),
    'UBP': ('Ubon Ratchathani', 'อุบลราชธานี', 'Ubon Ratchathani', 'อุบลราชธานี'),
    'KKC': ('Khon Kaen', 'ขอนแก่น', 'Khon Kaen', 'ขอนแก่น'),
    'TST': ('Trang', 'ตรัง', 'Trang', 'ตรัง'),
    'NNT': ('Nan Nakhon', 'น่านนคร', 'Nan', 'น่าน'),
    'CJM': ('Chumphon', 'ชุมพร', 'Chumphon', 'ชุมพร'),
    'TDX': ('Trat', 'ตราด', 'Trat', 'ตราด'),
    'ROI': ('Roi Et', 'ร้อยเอ็ด', 'Roi Et', 'ร้อยเอ็ด'),
    'HGN': ('Mae Hong Son', 'แม่ฮ่องสอน', 'Mae Hong Son', 'แม่ฮ่องสอน'),
    'SNO': ('Sakon Nakhon', 'สกลนคร', 'Sakon Nakhon', 'สกลนคร'),
    'NAW': ('Narathiwat', 'นราธิวาส', 'Narathiwat', 'นราธิวาส'),
    'KOP': ('Nakhon Phanom', 'นครพนม', 'Nakhon Phanom', 'นครพนม'),
    'PRH': ('Phrae', 'แพร่', 'Phrae', 'แพร่'),
    'NAK': ('Nakhon Ratchasima', 'นครราชสีมา', 'Nakhon Ratchasima', 'นครราชสีมา'),
    'BTZ': ('Betong', 'เบตง', 'Betong', 'เบตง'),
    'PHY': ('Phetchabun', 'เพชรบูรณ์', 'Phetchabun', 'เพชรบูรณ์'),
    'PYY': ('Pai', 'ปาย', 'Pai', 'ปาย'),
    'TKT': ('Tak', 'ตาก', 'Tak', 'ตาก'),
}

# International destinations used by promotions (not in the CSV).
INTERNATIONAL = [
    {'code': 'NRT', 'icao': 'RJAA', 'nameEn': 'Narita', 'nameTh': 'นาริตะ',
     'cityEn': 'Tokyo', 'cityTh': 'โตเกียว', 'countryCode': 'JP'},
    {'code': 'ICN', 'icao': 'RKSI', 'nameEn': 'Incheon', 'nameTh': 'อินชอน',
     'cityEn': 'Seoul', 'cityTh': 'โซล', 'countryCode': 'KR'},
    {'code': 'SIN', 'icao': 'WSSS', 'nameEn': 'Changi', 'nameTh': 'ชางงี',
     'cityEn': 'Singapore', 'cityTh': 'สิงคโปร์', 'countryCode': 'SG'},
]

# Keep in sync with lib/data/thai_airlines.dart.
AIRLINES = [
    {'code': 'TG', 'nameEn': 'Thai Airways', 'nameTh': 'การบินไทย',
     'hubs': ['BKK'], 'international': True, 'color': '#5C2D91'},
    {'code': 'FD', 'nameEn': 'Thai AirAsia', 'nameTh': 'ไทยแอร์เอเชีย',
     'hubs': ['DMK', 'BKK'], 'international': True, 'color': '#E4002B'},
    {'code': 'PG', 'nameEn': 'Bangkok Airways', 'nameTh': 'บางกอกแอร์เวย์ส',
     'hubs': ['BKK', 'USM'], 'international': False, 'color': '#00549F'},
    {'code': 'VZ', 'nameEn': 'Thai Vietjet', 'nameTh': 'ไทยเวียตเจ็ท',
     'hubs': ['BKK'], 'international': True, 'color': '#D6001C'},
    {'code': 'SL', 'nameEn': 'Thai Lion Air', 'nameTh': 'ไทยไลอ้อนแอร์',
     'hubs': ['DMK'], 'international': True, 'color': '#B5121B'},
    {'code': 'DD', 'nameEn': 'Nok Air', 'nameTh': 'นกแอร์',
     'hubs': ['DMK'], 'international': False, 'color': '#F2A900'},
    {'code': 'XJ', 'nameEn': 'Thai AirAsia X', 'nameTh': 'ไทยแอร์เอเชีย เอ็กซ์',
     'hubs': ['DMK'], 'international': True, 'color': '#C8102E'},
]


def num(value):
    value = value.strip().replace(',', '')
    return int(value) if value and value != '-' else 0


def main(csv_path):
    with open(csv_path, encoding='cp1252', newline='') as f:
        # Some headers are padded with spaces (" Total_Passenger ").
        rows = [{k.strip(): v for k, v in r.items()} for r in csv.DictReader(f)]

    latest = max((int(r['Year']), int(r['MonthNo'])) for r in rows)
    ly, lm = latest
    window_start = (ly - 1, lm + 1) if lm < 12 else (ly, 1)

    info = {}
    monthly = defaultdict(lambda: defaultdict(lambda: {'pax': 0, 'mov': 0, 'freightKg': 0}))
    last12 = defaultdict(lambda: {'pax': 0, 'mov': 0, 'domPax': 0, 'intPax': 0, 'schedPax': 0})

    for r in rows:
        iata = r['Airport Code(IATA)'].strip()
        if iata not in THAI_NAMES:
            continue  # e.g. Mae Sariang has no IATA code
        info.setdefault(iata, {
            'icao': r['Airport Code(ICAO)'].strip(),
            'operator': r['Airport Operator'].strip(),
        })
        ym = (int(r['Year']), int(r['MonthNo']))
        pax, mov = num(r['Total_Passenger']), num(r['Airport_Movements'])
        m = monthly[iata][ym]
        m['pax'] += pax
        m['mov'] += mov
        m['freightKg'] += num(r['Total_Freight_kg'])
        if window_start <= ym <= latest:
            s = last12[iata]
            s['pax'] += pax
            s['mov'] += mov
            s['domPax' if r['Dom / Int'] == 'Domestic' else 'intPax'] += pax
            if r['Sche / Non-Sche'] == 'Schedule':
                s['schedPax'] += pax

    # Only airports with scheduled passengers in the last 12 months are bookable.
    active = [c for c in info if last12[c]['schedPax'] > 0]
    active.sort(key=lambda c: -last12[c]['pax'])

    airports = []
    for rank, code in enumerate(active, start=1):
        nameEn, nameTh, cityEn, cityTh = THAI_NAMES[code]
        s = last12[code]
        airports.append({
            'code': code, 'icao': info[code]['icao'],
            'nameEn': nameEn, 'nameTh': nameTh, 'cityEn': cityEn, 'cityTh': cityTh,
            'countryCode': 'TH', 'operator': info[code]['operator'],
            'rank': rank, 'passengers12m': s['pax'], 'movements12m': s['mov'],
            'domesticPassengers12m': s['domPax'], 'internationalPassengers12m': s['intPax'],
        })
    airports += [dict(a, rank=0, passengers12m=0, movements12m=0) for a in INTERNATIONAL]

    period = f'{window_start[0]}-{window_start[1]:02d}..{ly}-{lm:02d}'
    stats = [{
        'code': code,
        'period12m': period,
        'monthly': [
            {'year': y, 'month': mo, **v}
            for (y, mo), v in sorted(monthly[code].items())
        ],
    } for code in active]

    seed = {
        'source': 'Air Transport Statistics (AOT / DOA / PG-UTP), monthly 2019-2026',
        'generatedOn': date.today().isoformat(),
        'period12m': period,
        'airlines': AIRLINES,
        'airports': airports,
        'airportStats': stats,
    }
    out_json = ROOT / 'backend' / 'seed' / 'firestore_seed.json'
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(seed, ensure_ascii=False, indent=1), encoding='utf-8')

    lines = [
        '// GENERATED by tool/build_airport_data.py — do not edit by hand.',
        f'// Source: Air Transport Statistics, ranked by passengers {period}.',
        "import '../models/entities.dart';",
        '',
        'const thaiAirports = <AirportEntity>[',
    ]
    for a in airports:
        lines += [
            '  AirportEntity(',
            f"    code: '{a['code']}',",
            f"    icao: '{a['icao']}',",
            f"    cityEn: '{a['cityEn']}',",
            f"    cityTh: '{a['cityTh']}',",
            f"    nameEn: '{a['nameEn']}',",
            f"    nameTh: '{a['nameTh']}',",
            f"    countryCode: '{a['countryCode']}',",
            f"    rank: {a['rank']},",
            f"    passengers12m: {a['passengers12m']},",
            '  ),',
        ]
    lines.append('];')
    out_dart = ROOT / 'lib' / 'data' / 'thai_airports.dart'
    out_dart.write_text('\n'.join(lines) + '\n', encoding='utf-8')

    print(f'{len(active)} Thai airports ({period}); top 5:')
    for a in airports[:5]:
        print(f"  {a['rank']}. {a['code']} {a['passengers12m']:,} pax")
    skipped = sorted(set(info) - set(active))
    if skipped:
        print('Skipped (no scheduled passengers in window):', ', '.join(skipped))


if __name__ == '__main__':
    main(sys.argv[1])
