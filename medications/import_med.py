import pandas as pd
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'med_project.settings')
django.setup()
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(BASE_DIR)

from medications.models import Drug

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# 讀 CSV（自動處理 BOM🔥）
df = pd.read_csv(
    os.path.join(BASE_DIR, '全部藥品許可證資料集.csv'),
    encoding='utf-8-sig'
)

# 去掉欄位空白（超重要🔥）
df.columns = df.columns.str.strip()

for _, row in df.iterrows():

    license = str(row.get('許可證字號', '')).strip()

    if not license:
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

print("匯入完成")