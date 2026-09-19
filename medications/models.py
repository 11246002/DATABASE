from django.db import models
from django.utils import timezone
from datetime import timedelta
from accounts.models import User


class Drug(models.Model):
    license = models.CharField(max_length=100)
    med_ch = models.CharField(max_length=100)
    med_en = models.CharField(max_length=100, blank=True, null=True)
    color = models.CharField(max_length=50, blank=True, null=True)
    shape = models.CharField(max_length=50, blank=True, null=True)
    indications = models.TextField(blank=True, null=True)
    element = models.TextField(blank=True, null=True)
    dosage_form = models.CharField(max_length=50, blank=True, null=True)


class Prescription(models.Model):
    prescription_id = models.AutoField(primary_key=True)

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE
    )

    hospital_name = models.CharField(max_length=50)

    visit_date = models.DateTimeField()

    image = models.ImageField(
    upload_to='prescriptions/',
    null=True,
    blank=True
)

    def __str__(self):
        return f"藥單編號:{self.prescription_id} - {self.user.user_name} - {self.hospital_name}"


class DrugWarning(models.Model):
    warning_id = models.AutoField(primary_key=True)

    drug = models.ForeignKey(
        Drug,
        on_delete=models.CASCADE
    )

    conflict_target = models.CharField(max_length=255)

    warning_desc = models.TextField()

    def __str__(self):
        return f"{self.drug.med_ch} - {self.conflict_target}"
    

class PrescriptionDrug(models.Model):

    raw_name = models.CharField(max_length=255)

    total_amount = models.IntegerField()

    drug = models.ForeignKey(
        Drug,
        on_delete=models.SET_NULL, 
        null=True,
        blank=True
    )

    prescription = models.ForeignKey(
        Prescription,
        on_delete=models.CASCADE
    )

    frequency = models.CharField(max_length=20)

    days = models.IntegerField()

    remaining_amount = models.IntegerField(
        null=True,
        blank=True
    )

    def __str__(self):
        return f"藥單編號:{self.prescription.prescription_id},藥品編號:{self.id} - {self.raw_name} ({self.frequency})"
    

class Remind(models.Model):

    remind_id = models.AutoField(primary_key=True)

    prescription_drug = models.ForeignKey(
        PrescriptionDrug,
        on_delete=models.CASCADE
    )

    frequency_tag = models.CharField(max_length=50)

    remind_time = models.TimeField()

    is_active = models.BooleanField(default=True)

    @property
    def start_date(self):
        """服藥起始日 (來自 Prescription.visit_date)"""
        if self.prescription_drug and self.prescription_drug.prescription and self.prescription_drug.prescription.visit_date:
            v = self.prescription_drug.prescription.visit_date
            return v.date() if hasattr(v, 'date') else v
        return None

    @property
    def end_date(self):
        """服藥結束日 (start_date + days - 1)"""
        s = self.start_date
        if s and self.prescription_drug and self.prescription_drug.days and self.prescription_drug.days > 0:
            return s + timedelta(days=self.prescription_drug.days - 1)
        return None

    @property
    def is_expired(self):
        """判斷該鬧鐘是否已過期 (以目前日期與 end_date 比對)"""
        end = self.end_date
        if end:
            return timezone.localdate() > end
        return False

    def delete(self, using=None, keep_parents=False, force=False):
        """軟刪除：將 is_active 設為 False，避免外鍵 CASCADE 連帶清空 TakingRecord 歷史"""
        if force:
            return super().delete(using=using, keep_parents=keep_parents)
        self.is_active = False
        self.save(update_fields=['is_active'])

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['prescription_drug', 'frequency_tag'],
                name='unique_prescription_drug_frequency_tag'
            )
        ]

    def __str__(self):
        return f"{self.remind_id}-{self.prescription_drug.raw_name} - {self.frequency_tag} at {self.remind_time}"
    

class TakingRecord(models.Model):

    takingrecord_id = models.AutoField(primary_key=True)

    remind = models.ForeignKey(
        Remind,
        on_delete=models.CASCADE
    )

    status = models.CharField(max_length=20)

    # 專門記錄打卡日期，配合 unique constraint 達到資料庫層級防重複打卡
    record_date = models.DateField(default=timezone.localdate)

    taken_at = models.DateTimeField(default=timezone.now)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['remind', 'record_date'],
                name='unique_remind_record_date'
            )
        ]

    def __str__(self):
        return f"{self.remind} - date:{self.record_date} time:\"{self.taken_at}\" - {self.status}"


# ==========================================
# 健康存摺同步 - 歷史藥歷紀錄
# ==========================================
class MedicationHistory(models.Model):

    history_id = models.AutoField(primary_key=True)

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        null=True,
        blank=True
    )

    drug_code = models.CharField(max_length=50)           # 健保藥品代碼（如 BC24512100）

    drug_name = models.CharField(max_length=255)          # 藥品名稱（如 Candesartan）

    dosage = models.CharField(max_length=50)              # 劑量（如 8mg）

    frequency = models.CharField(max_length=50)           # 頻率（如 QD、BID、TID）

    days = models.IntegerField()                          # 給藥天數

    hosp_name = models.CharField(max_length=100)          # 開立醫療院所名稱

    rx_date = models.DateField()                          # 處方開立日期

    synced_at = models.DateTimeField(auto_now_add=True)   # 資料同步時間（自動記錄）

    def __str__(self):
        return f"{self.user} - {self.drug_name} ({self.rx_date})"


# ==========================================
# 健康存摺同步 - 患者過敏原紀錄
# ==========================================
class PatientAllergy(models.Model):

    allergy_id = models.AutoField(primary_key=True)

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        null=True,
        blank=True
    )

    allergen_name = models.CharField(max_length=255)      # 過敏原名稱（如 Amoxicillin）

    reaction = models.TextField(blank=True, null=True)    # 過敏反應描述（如 皮膚紅疹、搔癢）

    synced_at = models.DateTimeField(auto_now_add=True)   # 資料同步時間（自動記錄）

    def __str__(self):
        return f"{self.user} - 過敏原：{self.allergen_name}"
