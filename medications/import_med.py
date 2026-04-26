import sys
import os
import csv

sys.path.insert(0, r'C:\Users\user\Documents\durgAPP\med_project')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'med_project.settings')

import django
django.setup()

from medications.models import Drug

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# ===== 檔案 A =====
with open(os.path.join(BASE_DIR, '全部藥品許可證資料集.csv'), encoding='utf-8') as file:
    reader = csv.DictReader(file)
    for row in reader:
        license = row.get('許可證字號')
        if not license:  # 跳過空值
            continue
        Drug.objects.get_or_create(
            license=license,
            defaults={
                'med_ch': row.get('中文品名'),
                'med_en': row.get('英文品名'),
                'indications': row.get('適應症'),
                'dosage_form': row.get('劑型'),
                'element': row.get('主成分略述'),
            }
        )

# ===== 檔案 B =====
with open(os.path.join(BASE_DIR, '藥品外觀資料集.csv'), encoding='utf-8') as file:
    reader = csv.DictReader(file)
    for row in reader:
        license = row.get('許可證字號')
        if not license:  # 跳過空值
            continue
        drug, created = Drug.objects.get_or_create(license=license)
        drug.shape = row.get('形狀')
        drug.color = row.get('顏色')
        drug.save()